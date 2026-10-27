import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../data/tasks_repository.dart';
import '../domain/task.dart';

/// Na prototipação, o fake em memória; no bloco de integração, o Firestore.
final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  final repository = FakeTasksRepository(clock: ref.watch(clockProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

final tasksProvider = StreamProvider<List<NexoTask>>(
  (ref) => ref.watch(tasksRepositoryProvider).watchTasks(),
);
