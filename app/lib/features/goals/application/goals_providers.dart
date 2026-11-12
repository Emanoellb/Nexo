import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../../core/data/firestore_access.dart';
import '../data/firestore_goals_repository.dart';
import '../data/goals_repository.dart';
import '../domain/goal.dart';

/// Firestore (`users/{uid}/…`), com o uid verificado: sem login ou antes de
/// verificar o e-mail, listas vazias. Trocar de conta recria.
final goalsRepositoryProvider = Provider<GoalsRepository>(
  (ref) => FirestoreGoalsRepository(
    ref.watch(firestoreAccessProvider),
    uid: ref.watch(verifiedUidProvider),
  ),
);

final goalsProvider = StreamProvider<List<Goal>>(
  (ref) => ref.watch(goalsRepositoryProvider).watchGoals(),
);
