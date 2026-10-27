import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/goals_repository.dart';
import '../domain/goal.dart';

/// Na prototipação, o fake em memória; no bloco de integração, o Firestore.
final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  final repository = FakeGoalsRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final goalsProvider = StreamProvider<List<Goal>>(
  (ref) => ref.watch(goalsRepositoryProvider).watchGoals(),
);
