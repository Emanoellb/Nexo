import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_user.dart';
import 'auth_repository.dart';

/// Autenticação real (Firebase Auth), pendências A1 e A2 do
/// firebase-setup.md §11.2:
/// - e-mails do Firebase em pt-BR (`setLanguageCode`, A1.3);
/// - erros pelo [authFailureFromCode] (A1.1 e A1.2);
/// - reset sem `ActionCodeSettings` (página padrão, A1.4);
/// - Google pelo `google_sign_in` 7: `initialize` + `authenticate`, e o
///   `idToken` vira credencial do Firebase. O Android lê o client web do
///   `default_web_client_id` (gerado do google-services.json).
///
/// A política de senha (R5, A1.5) é conferida no app (`AuthRules`), pelo
/// `validatePassword` antes de criar a conta e pelo Firebase no cadastro
/// (`password-does-not-meet-requirements`).
///
/// Tudo espera [ready] (a carga do Firebase, feita durante a splash).
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({required this.ready});

  /// A carga do Firebase (`Firebase.initializeApp`), feita na splash.
  final Future<void> ready;
  Future<void>? _googleReady;

  fb.FirebaseAuth get _auth => fb.FirebaseAuth.instance;

  /// Liga o pt-BR uma vez, depois da carga do Firebase.
  late final Future<void> _setUp = ready.then(
    (_) => _auth.setLanguageCode('pt-BR'),
  );

  Future<void> _google() => _googleReady ??= GoogleSignIn.instance.initialize();

  static AuthUser? _map(fb.User? user) => user == null
      ? null
      : AuthUser(
          uid: user.uid,
          emailVerified: user.emailVerified,
          signedInWithGoogle: user.providerData.any(
            (p) => p.providerId == 'google.com',
          ),
          email: user.email,
          displayName: user.displayName,
        );

  /// Converte as exceções do Firebase em [AuthFailure].
  Future<T> _guard<T>(Future<T> Function() action) async {
    await _setUp;
    try {
      return await action();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(authFailureFromCode(e.code));
    }
  }

  @override
  Stream<AuthUser?> authStateChanges() async* {
    await _setUp;
    // userChanges: também avisa quando o e-mail é verificado (reload).
    yield* _auth.userChanges().map(_map);
  }

  @override
  AuthUser? get currentUser {
    try {
      return _map(_auth.currentUser);
    } on Object {
      // Firebase ainda carregando.
      return null;
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _guard(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) => _guard(() async {
    await _checkPasswordPolicy(password);
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.sendEmailVerification();
  });

  /// R5 (A1.5): confere a senha contra a política do console antes de criar
  /// a conta. Se a consulta da política falhar (sem internet, ou a chave de
  /// API restrita ao app Android [NC]), o cadastro segue: o app já confere a
  /// R5 (`AuthRules`) e o Firebase recusa no cadastro
  /// (`password-does-not-meet-requirements`).
  Future<void> _checkPasswordPolicy(String password) async {
    final bool valid;
    try {
      valid = (await _auth.validatePassword(_auth, password)).isValid;
    } on Object {
      return;
    }
    if (!valid) throw const AuthFailure(AuthFailureCode.weakPassword);
  }

  /// O idToken do Google, ou `null` se a pessoa fechar a escolha de conta.
  Future<fb.AuthCredential?> _googleCredential() async {
    await _google();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const AuthFailure(AuthFailureCode.unknown);
      return fb.GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw const AuthFailure(AuthFailureCode.unknown);
    }
  }

  @override
  Future<AuthUser?> signInWithGoogle() => _guard(() async {
    final credential = await _googleCredential();
    if (credential == null) return null;
    final result = await _auth.signInWithCredential(credential);
    return _map(result.user);
  });

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> sendEmailVerification() =>
      _guard(() async => _auth.currentUser?.sendEmailVerification());

  @override
  Future<bool> refreshEmailVerified() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    // Token novo antes do reload: as regras passam a ver email_verified
    // (firebase-setup §6). O reload é que avisa a verificação
    // (userChanges), e aí o perfil começa a ser lido; com o token velho, a
    // leitura seria recusada.
    await user.getIdToken(true);
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  });

  @override
  Future<void> deleteCurrentUser() => _guard(() async {
    final user = _auth.currentUser;
    final google = _map(user)?.signedInWithGoogle ?? false;
    await user?.delete();
    if (google) await _googleSignOut();
  });

  @override
  Future<void> reauthenticateWithPassword(String password) => _guard(() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthFailure(AuthFailureCode.invalidCredential);
    }
    await user.reauthenticateWithCredential(
      fb.EmailAuthProvider.credential(email: email, password: password),
    );
  });

  @override
  Future<bool> reauthenticateWithGoogle() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final credential = await _googleCredential();
    if (credential == null) return false;
    await user.reauthenticateWithCredential(credential);
    return true;
  });

  Future<void> _googleSignOut() async {
    try {
      await _google();
      await GoogleSignIn.instance.signOut();
    } on Object {
      // Sem sessão Google no aparelho: nada a fazer.
    }
  }

  @override
  Future<void> signOut() async {
    await _setUp;
    await _googleSignOut();
    await _auth.signOut();
  }
}
