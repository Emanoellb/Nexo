import '../domain/auth_user.dart';

/// Autenticação do app. A implementação real (`FirebaseAuthRepository`,
/// pendência A1 de firebase-setup.md §11.2) entra no bloco do fluxo de entrada.
abstract interface class AuthRepository {
  /// Emite o usuário atual e cada mudança (login, logout, verificação).
  Stream<AuthUser?> authStateChanges();

  Future<void> signOut();
}

/// Leitura do documento `users/{uid}`.
abstract interface class UserProfileRepository {
  /// `null` enquanto o documento não existe (ex.: primeiro login Google).
  Stream<UserProfile?> watchProfile(String uid);
}
