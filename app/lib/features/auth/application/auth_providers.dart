import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firebase_ready.dart';
import '../../../core/data/firestore_access.dart';
import '../data/auth_repository.dart';
import '../data/firebase_auth_repository.dart';
import '../data/firestore_user_profile_repository.dart';
import '../domain/auth_user.dart';
import '../domain/entry_status.dart';
import 'account_deletion.dart';

/// Firebase Auth, depois da carga do Firebase (feita na splash).
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(ready: ref.watch(firebaseReadyProvider)),
);

/// Fuso IANA do aparelho, gravado em `users/{uid}.timeZone`. O `main` lê
/// pelo canal `nexo/device` (sem pacote) e normaliza
/// (`normalizeTimeZone`); sem leitura, o padrão do Brasil.
final deviceTimeZoneProvider = Provider<String>((ref) => 'America/Sao_Paulo');

/// `users/{uid}` no Firestore.
final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => FirestoreUserProfileRepository(ref.watch(firestoreAccessProvider)),
);

final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// uid da sessão atual (`null` sem login). Os repositórios de dados usam o
/// [verifiedUidProvider].
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider.select((auth) => auth.value?.uid)),
);

/// uid só com o e-mail verificado: as regras só liberam os dados de
/// `users/{uid}` assim. É o uid dos repositórios do Firestore.
final verifiedUidProvider = Provider<String?>(
  (ref) => ref.watch(
    authStateProvider.select((auth) {
      final user = auth.value;
      return user != null && user.emailVerified ? user.uid : null;
    }),
  ),
);

/// Perfil do usuário logado; `null` sem login ou sem documento. Só escuta
/// depois da verificação do e-mail: antes, as regras recusam a leitura de
/// `users/{uid}` (e a entrada nem olha o perfil, vai para a tela 05).
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || !user.emailVerified) return Stream.value(null);
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
    deletionRunning: ref.watch(accountDeletionRunningProvider),
  );
});
