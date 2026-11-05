import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../../auth/application/auth_providers.dart';
import '../data/tasks_repository.dart';
import '../domain/task.dart';

/// Na prototipação, o fake em memória; no bloco de integração, o Firestore.
/// Um por conta: trocar de conta recria (dados de `users/{uid}`).
final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  ref.watch(currentUidProvider);
  final repository = FakeTasksRepository(clock: ref.watch(clockProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

final tasksProvider = StreamProvider<List<NexoTask>>(
  (ref) => ref.watch(tasksRepositoryProvider).watchTasks(),
);
