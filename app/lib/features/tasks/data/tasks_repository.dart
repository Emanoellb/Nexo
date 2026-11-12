import '../domain/task.dart';

/// `users/{uid}/tasks` (Firestore: `FirestoreTasksRepository`).
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
