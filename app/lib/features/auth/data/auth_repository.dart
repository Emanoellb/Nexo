import '../domain/auth_user.dart';

/// Autenticação do app (Firebase Auth: `FirebaseAuthRepository`).
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

  /// Apaga a conta do Auth logo após o login (menor de 16 na 03b) e no fim
  /// do Excluir conta.
  Future<void> deleteCurrentUser();

  /// Excluir conta, passo 2: entrar de novo com a senha. Lança
  /// `AuthFailure` se a senha não confere.
  Future<void> reauthenticateWithPassword(String password);

  /// Excluir conta, passo 2, conta Google. `false` se a pessoa fechar a
  /// escolha de conta.
  Future<bool> reauthenticateWithGoogle();

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

  /// Soma [delta] a `users.points`, sem sair de 0 a [UserProfile.maxPoints]
  /// (limites das regras).
  Future<void> addPoints(String uid, int delta);

  /// Grava `users.primaryPlanId` (`null` limpa).
  Future<void> setPrimaryPlan(String uid, String? planId);

  /// Editar perfil: só o nome (1 a 80).
  Future<void> updateDisplayName(String uid, String name);

  /// Perfil: limite de tarefas por dia (1 a 20).
  Future<void> setOverloadThreshold(String uid, int threshold);

  /// Perfil: Aviso da manhã.
  Future<void> setMorningSummary(String uid, MorningSummary summary);

  /// Excluir conta, passo 3: grava `deletionRequestedAt` (carimbo do
  /// servidor; uma vez só, não se desfaz).
  Future<void> markDeletionRequested(String uid);

  /// Excluir conta: apaga `users/{uid}` (depois dos dados).
  Future<void> deleteProfile(String uid);
}
