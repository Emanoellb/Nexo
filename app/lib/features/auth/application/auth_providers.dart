import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/fake_auth_repository.dart';
import '../domain/auth_user.dart';
import '../domain/entry_status.dart';

/// Repositório de auth. Na prototipação, o fake (sem Firebase), que começa
/// sem sessão; a troca pelo `FirebaseAuthRepository` é feita aqui, no bloco
/// de integração.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = FakeAuthRepository.prototype();
  ref.onDispose(repository.dispose);
  return repository;
});

/// Fuso IANA do aparelho, gravado em `users/{uid}.timeZone`. Fixo na
/// prototipação: ler o fuso real pede um pacote novo (ex. flutter_timezone),
/// a aprovar no bloco de integração.
final deviceTimeZoneProvider = Provider<String>((ref) => 'America/Sao_Paulo');

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final repository = FakeUserProfileRepository.prototype();
  ref.onDispose(repository.dispose);
  return repository;
});

final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// uid da sessão atual (`null` sem login). Os repositórios de dados assistem
/// a ele: cada conta tem os próprios dados, como em `users/{uid}` no
/// Firestore (decisão do usuário, 05/11/2026).
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider.select((auth) => auth.value?.uid)),
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
    // Recarregando conta como carregando, mesmo com valor anterior: na troca
    // de usuário o Riverpod mantém o perfil antigo (`null`), que seria lido
    // como "sem perfil" e levaria à 03b (achado [3] da revisão, 04/11/2026).
    profileLoading: profile.isLoading,
    profile: profile.value,
  );
});
