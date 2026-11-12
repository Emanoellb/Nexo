import 'package:nexo/features/tasks/data/tasks_repository.dart';
import 'package:nexo/features/tasks/domain/task.dart';
import 'package:nexo/features/tasks/domain/task_rules.dart';

import 'in_memory_store.dart';

class FakeTasksRepository implements TasksRepository {
  FakeTasksRepository({required this.clock});

  /// Relógio injetável (testes usam horário fixo).
  final DateTime Function() clock;
  final _ids = FakeIds('tarefa');
  final _tasks = InMemoryStore<NexoTask>(const [], (t) => t.id);

  @override
  Stream<List<NexoTask>> watchTasks() => _tasks.watch(sort: compareTasksByDue);

  @override
  Future<NexoTask> createTask(NexoTask draft) async {
    final task = NexoTask(
      id: _ids.next(),
      title: draft.title,
      priority: draft.priority,
      subjectId: draft.subjectId,
      dueAt: draft.dueAt,
      remindersMinutesBefore: draft.remindersMinutesBefore,
      deliveryStatus: draft.deliveryStatus,
    ).withCompleted(draft.completed, now: clock());
    _tasks.put(task);
    return task;
  }

  @override
  Future<void> updateTask(NexoTask task) async => _tasks.put(task);

  @override
  Future<int> setCompleted(String taskId, bool completed) async {
    final task = _tasks.get(taskId);
    if (task == null) throw StateError('Tarefa $taskId não existe.');
    _tasks.put(task.withCompleted(completed, now: clock()));
    return taskPointsDelta(
      wasCompleted: task.completed,
      isCompleted: completed,
    );
  }

  @override
  Future<int> deleteTask(String taskId) async {
    final task = _tasks.get(taskId);
    if (task == null) return 0;
    _tasks.remove(taskId);
    return taskPointsDelta(wasCompleted: task.completed, isCompleted: false);
  }

  void dispose() => _tasks.dispose();
}
