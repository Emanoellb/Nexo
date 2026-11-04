import '../domain/auth_user.dart';

/// Autenticação do app. A implementação real (`FirebaseAuthRepository`,
/// pendência A1 de firebase-setup.md §11.2) entra no bloco de integração.
///
/// Os métodos lançam `AuthFailure` (auth_failure.dart) nos erros que a
/// interface trata.
abstract interface class AuthRepository {
  /// Emite o usuário atual e cada mudança (login, logout, verificação).
  Stream<AuthUser?> authStateChanges();

  AuthUser? get currentUser;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  /// Cria a conta de e-mail e senha, entra com ela e envia o e-mail de
  /// verificação (tela 05).
  Future<void> createAccount({required String email, required String password});

  /// Login Google. `null` se o usuário fechar a escolha de conta.
  Future<AuthUser?> signInWithGoogle();

  /// Pede o link de redefinição. Com a enumeration protection, termina sem
  /// erro mesmo se a conta não existir (mensagem neutra na tela 04).
  Future<void> sendPasswordResetEmail(String email);

  Future<void> sendEmailVerification();

  /// `reload()` + `getIdToken(true)`: devolve se o e-mail já foi confirmado
  /// ("Já confirmei" da tela 05).
  Future<bool> refreshEmailVerified();

  /// Apaga a conta do Auth logo após o login (menor de 16 na 03b).
  Future<void> deleteCurrentUser();

  Future<void> signOut();
}

/// Documento `users/{uid}`. Os métodos lançam `DataFailure`
/// (core/data/data_failure.dart) nos erros de leitura ou gravação.
abstract interface class UserProfileRepository {
  /// `null` enquanto o documento não existe (ex.: primeiro login Google).
  Stream<UserProfile?> watchProfile(String uid);

  /// Cria `users/{uid}` no Cadastro e na 03b, com o aceite.
  Future<void> createProfile(String uid, NewUserProfile profile);

  /// Grava `tutorialSeen: true` ("Começar" no fim do tutorial).
  Future<void> markTutorialSeen(String uid);
}
