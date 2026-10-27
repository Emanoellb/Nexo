import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/fake_auth_repository.dart';
import '../domain/auth_user.dart';
import '../domain/entry_status.dart';

/// Repositório de auth. Na prototipação, o fake (sem Firebase); a troca pelo
/// `FirebaseAuthRepository` é feita aqui, no bloco de integração.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = FakeAuthRepository.prototype();
  ref.onDispose(repository.dispose);
  return repository;
});

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final repository = FakeUserProfileRepository.prototype();
  ref.onDispose(repository.dispose);
  return repository;
});

final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Perfil do usuário logado; `null` sem login ou sem documento.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(userProfileRepositoryProvider).watchProfile(user.uid);
});

final entryStatusProvider = Provider<EntryStatus>((ref) {
  final auth = ref.watch(authStateProvider);
  final profile = ref.watch(userProfileProvider);
  return resolveEntryStatus(
    authLoading: auth.isLoading && !auth.hasValue,
    user: auth.value,
    profileLoading: profile.isLoading && !profile.hasValue,
    profile: profile.value,
  );
});
