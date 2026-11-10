import 'dart:async';

import '../domain/auth_failure.dart';
import '../domain/auth_rules.dart';
import '../../../core/domain/local_date.dart';
import '../domain/auth_user.dart';
import 'auth_repository.dart';

class _FakeAccount {
  _FakeAccount({
    required this.uid,
    required this.email,
    this.password,
    this.verified = false,
    this.google = false,
    this.displayName,
  });

  final String uid;
  final String email;
  final String? password;
  bool verified;
  final bool google;
  final String? displayName;

  AuthUser toUser() => AuthUser(
    uid: uid,
    emailVerified: verified,
    signedInWithGoogle: google,
    email: email,
    displayName: displayName,
  );
}

/// Auth em memória para a prototipação (auth simulado até o fim da
/// prototipação, decisão de 27/10/2026). Não toca no Firebase.
///
/// Roteiro de teste no aparelho (dados fictícios):
/// - conta pronta: [prototypeEmail] / [prototypePassword];
/// - e-mails gatilho (Login, Cadastro e Esqueci a senha), com qualquer
///   domínio: `sem-conexao@…` (sem internet), `muitas-tentativas@…`
///   (bloqueio) e `erro@…` (erro genérico);
/// - 5 senhas erradas seguidas para o mesmo e-mail também bloqueiam;
/// - Cadastro com [prototypeEmail]: "Este e-mail já tem uma conta";
/// - conta nova: o 1º "Já confirmei" ainda não encontra a confirmação; o 2º
///   confirma;
/// - Google: sempre a conta [googleEmail], sem perfil na 1ª vez (vai à 03b).
///
/// A sessão fica só na memória: cada abertura do app começa no Login.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    AuthUser? initialUser,
    bool withPrototypeAccounts = false,
    this.latency = Duration.zero,
  }) : _user = initialUser {
    if (withPrototypeAccounts) {
      _add(
        _FakeAccount(
          uid: prototypeUser.uid,
          email: prototypeEmail,
          password: prototypePassword,
          verified: true,
        ),
      );
    }
    _add(
      _FakeAccount(
        uid: 'google-ana',
        email: googleEmail,
        verified: true,
        google: true,
        displayName: 'Ana Souza',
      ),
    );
  }

  /// Protótipo no aparelho: começa sem sessão e com a conta pronta. A espera
  /// simulada deixa ver os estados de carregamento.
  factory FakeAuthRepository.prototype() => FakeAuthRepository(
    withPrototypeAccounts: true,
    latency: const Duration(milliseconds: 700),
  );

  /// Já logado com a conta pronta (testes do app com sessão).
  factory FakeAuthRepository.signedIn() => FakeAuthRepository(
    initialUser: prototypeUser,
    withPrototypeAccounts: true,
  );

  /// Conta fictícia da prototipação. Não é credencial real de ninguém.
  static const prototypeEmail = 'ana.souza@email.com';
  static const prototypePassword = 'Nexo#2026';
  static const googleEmail = 'ana.souza@gmail.com';

  /// uid da conta de protótipo (constante, para comparações em `const`).
  static const prototypeUserUid = 'prototipo';

  static const prototypeUser = AuthUser(
    uid: prototypeUserUid,
    emailVerified: true,
    email: prototypeEmail,
  );

  /// Tentativas erradas seguidas antes do bloqueio simulado.
  static const maxFailedAttempts = 5;

  final Duration latency;
  final _accounts = <String, _FakeAccount>{};
  final _failedAttempts = <String, int>{};
  final _verificationChecks = <String, int>{};
  var _nextId = 1;

  AuthUser? _user;
  final _controller = StreamController<AuthUser?>.broadcast();

  void _add(_FakeAccount account) => _accounts[account.email] = account;

  @override
  AuthUser? get currentUser => _user;

  /// Para testes: troca o usuário e avisa quem escuta.
  void setUser(AuthUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  Future<void> _wait() => Future<void>.delayed(latency);

  /// Erros disparados pelo e-mail (ver o roteiro acima).
  void _throwIfTrigger(String email) {
    final local = email.trim().toLowerCase().split('@').first;
    final code = switch (local) {
      'sem-conexao' => AuthFailureCode.network,
      'muitas-tentativas' => AuthFailureCode.tooManyRequests,
      'erro' => AuthFailureCode.unknown,
      _ => null,
    };
    if (code != null) throw AuthFailure(code);
  }

  String _key(String email) => email.trim().toLowerCase();

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _wait();
    _throwIfTrigger(email);
    final key = _key(email);
    if ((_failedAttempts[key] ?? 0) >= maxFailedAttempts) {
      throw const AuthFailure(AuthFailureCode.tooManyRequests);
    }
    final account = _accounts[key];
    if (account == null || account.password != password) {
      _failedAttempts[key] = (_failedAttempts[key] ?? 0) + 1;
      throw const AuthFailure(AuthFailureCode.invalidCredential);
    }
    _failedAttempts.remove(key);
    setUser(account.toUser());
  }

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    await _wait();
    _throwIfTrigger(email);
    final key = _key(email);
    if (!AuthRules.isValidEmail(key)) {
      throw const AuthFailure(AuthFailureCode.invalidEmail);
    }
    if (!AuthRules.meetsPasswordPolicy(password)) {
      throw const AuthFailure(AuthFailureCode.weakPassword);
    }
    if (_accounts.containsKey(key)) {
      throw const AuthFailure(AuthFailureCode.emailAlreadyInUse);
    }
    final account = _FakeAccount(
      uid: 'conta-${_nextId++}',
      email: key,
      password: password,
    );
    _add(account);
    setUser(account.toUser());
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    await _wait();
    final account = _accounts[googleEmail]!;
    setUser(account.toUser());
    return account.toUser();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _wait();
    _throwIfTrigger(email);
    if (!AuthRules.isValidEmail(email)) {
      throw const AuthFailure(AuthFailureCode.invalidEmail);
    }
    // Neutro: sucesso exista a conta ou não.
  }

  @override
  Future<void> sendEmailVerification() async {
    await _wait();
    final email = _user?.email;
    if (email != null) _throwIfTrigger(email);
  }

  @override
  Future<bool> refreshEmailVerified() async {
    await _wait();
    final user = _user;
    if (user == null) return false;
    final account = _accounts[user.email];
    if (account == null) return user.emailVerified;
    final checks = (_verificationChecks[user.uid] ?? 0) + 1;
    _verificationChecks[user.uid] = checks;
    if (checks >= 2) account.verified = true;
    if (account.verified && !user.emailVerified) {
      setUser(account.toUser());
    }
    return account.verified;
  }

  @override
  Future<void> deleteCurrentUser() async {
    await _wait();
    final user = _user;
    if (user == null) return;
    // A conta Google fictícia continua disponível para um novo teste.
    if (!user.signedInWithGoogle) _accounts.remove(user.email);
    setUser(null);
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    await _wait();
    final user = _user;
    final account = user?.email == null ? null : _accounts[_key(user!.email!)];
    if (account == null || account.password != password) {
      throw const AuthFailure(AuthFailureCode.invalidCredential);
    }
  }

  @override
  Future<bool> reauthenticateWithGoogle() async {
    await _wait();
    return _user?.signedInWithGoogle ?? false;
  }

  @override
  Future<void> signOut() async => setUser(null);

  void dispose() => _controller.close();
}

/// `users/{uid}` em memória.
class FakeUserProfileRepository implements UserProfileRepository {
  FakeUserProfileRepository({Map<String, UserProfile>? profiles})
    : _profiles = {...?profiles};

  factory FakeUserProfileRepository.prototype() => FakeUserProfileRepository(
    profiles: {
      FakeAuthRepository.prototypeUser.uid: const UserProfile(
        displayName: 'Ana',
        tutorialSeen: true,
        birthDate: LocalDate(2003, 3, 12),
      ),
    },
  );

  final Map<String, UserProfile> _profiles;
  final _controller = StreamController<String>.broadcast();

  /// O que o Cadastro e a 03b gravaram (para os testes conferirem).
  final created = <String, NewUserProfile>{};

  void setProfile(String uid, UserProfile? profile) {
    if (profile == null) {
      _profiles.remove(uid);
    } else {
      _profiles[uid] = profile;
    }
    _controller.add(uid);
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) async* {
    yield _profiles[uid];
    yield* _controller.stream
        .where((changed) => changed == uid)
        .map((_) => _profiles[uid]);
  }

  @override
  Future<void> createProfile(String uid, NewUserProfile profile) async {
    created[uid] = profile;
    setProfile(
      uid,
      UserProfile(
        displayName: profile.displayName,
        birthDate: profile.birthDate,
      ),
    );
  }

  @override
  Future<void> markTutorialSeen(String uid) async {
    final profile = _profiles[uid];
    if (profile == null) return;
    setProfile(uid, profile.copyWith(tutorialSeen: true));
  }

  @override
  Future<void> addPoints(String uid, int delta) async {
    final profile = _profiles[uid];
    if (profile == null || delta == 0) return;
    final points = (profile.points + delta).clamp(0, UserProfile.maxPoints);
    setProfile(uid, profile.copyWith(points: points));
  }

  @override
  Future<void> setPrimaryPlan(String uid, String? planId) async {
    final profile = _profiles[uid];
    if (profile == null) return;
    setProfile(uid, profile.copyWith(primaryPlanId: () => planId));
  }

  void _update(String uid, UserProfile Function(UserProfile) change) {
    final profile = _profiles[uid];
    if (profile != null) setProfile(uid, change(profile));
  }

  @override
  Future<void> updateDisplayName(String uid, String name) async =>
      _update(uid, (p) => p.copyWith(displayName: name.trim()));

  @override
  Future<void> setOverloadThreshold(String uid, int threshold) async =>
      _update(uid, (p) => p.copyWith(overloadThreshold: threshold));

  @override
  Future<void> setMorningSummary(String uid, MorningSummary summary) async =>
      _update(uid, (p) => p.copyWith(morningSummary: summary));

  /// Carimbo do "servidor" no fake (os testes podem trocar).
  DateTime Function() now = DateTime.now;

  @override
  Future<void> markDeletionRequested(String uid) async => _update(
    uid,
    (p) => p.deletionRequestedAt != null
        ? p
        : p.copyWith(deletionRequestedAt: now()),
  );

  @override
  Future<void> deleteProfile(String uid) async => setProfile(uid, null);

  void dispose() => _controller.close();
}
