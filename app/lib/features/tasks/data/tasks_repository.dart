import '../../../core/data/in_memory_store.dart';
import '../domain/task.dart';
import '../domain/task_rules.dart';

/// `users/{uid}/tasks`. A versão Firestore entra no bloco de integração.
abstract interface class TasksRepository {
  /// Pendentes primeiro, por prazo (sem prazo no fim); depois as concluídas.
  Stream<List<NexoTask>> watchTasks();

  Future<NexoTask> createTask(NexoTask draft);
  Future<void> updateTask(NexoTask task);

  /// Concluir ou reabrir, com a situação da entrega coerente no mesmo
  /// gravar. Devolve a variação de pontos (+1, −1 ou 0) para `users.points`.
  Future<int> setCompleted(String taskId, bool completed);

  /// Apaga a tarefa. Devolve a variação de pontos: −1 se ela estava
  /// concluída, como ao reabrir (decisão do usuário, 04/11/2026); senão 0.
  Future<int> deleteTask(String taskId);
}

class FakeTasksRepository implements TasksRepository {
  FakeTasksRepository({required this.clock});

  /// Relógio injetável (testes usam horário fixo).
  final DateTime Function() clock;
  final _ids = FakeIds('tarefa');
  final _tasks = InMemoryStore<NexoTask>(const [], (t) => t.id);

  static int _byDue(NexoTask a, NexoTask b) {
    if (a.completed != b.completed) return a.completed ? 1 : -1;
    final da = a.dueAt;
    final db = b.dueAt;
    if (da == null && db == null) return a.title.compareTo(b.title);
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  @override
  Stream<List<NexoTask>> watchTasks() => _tasks.watch(sort: _byDue);

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
