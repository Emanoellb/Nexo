import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/goals_repository.dart';
import '../domain/goal.dart';

/// Na prototipação, o fake em memória; no bloco de integração, o Firestore.
/// Um por conta: trocar de conta recria (dados de `users/{uid}`).
final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  ref.watch(currentUidProvider);
  final repository = FakeGoalsRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final goalsProvider = StreamProvider<List<Goal>>(
  (ref) => ref.watch(goalsRepositoryProvider).watchGoals(),
);
