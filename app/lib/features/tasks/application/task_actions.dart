import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../../auth/application/deferred_deletion.dart';
import '../../progress/application/progress_actions.dart';
import '../domain/task.dart';
import '../domain/task_rules.dart';
import 'tasks_providers.dart';

export '../../auth/application/deferred_deletion.dart';

/// Tarefas com exclusão pendente.
final pendingTaskDeletionsProvider =
    NotifierProvider<PendingDeletions, Set<String>>(PendingDeletions.new);

/// Excluir tarefa com "Desfazer" (pontos ajustados pelo `ProgressActions`).
final taskDeletionProvider = Provider<DeferredDeletion>(
  (ref) => DeferredDeletion(
    ref,
    pendingTaskDeletionsProvider,
    (id) => ref.read(progressActionsProvider).deleteTask(id),
  ),
);

/// As tarefas sem as de exclusão pendente: o que todas as telas mostram
/// (Início, Tarefas, disciplina).
final visibleTasksProvider = Provider<AsyncValue<List<NexoTask>>>((ref) {
  final pending = ref.watch(pendingTaskDeletionsProvider);
  return ref
      .watch(tasksProvider)
      .whenData(
        (tasks) => [
          for (final t in tasks)
            if (!pending.contains(t.id)) t,
        ],
      );
});

/// Ações da lista de tarefas que não mexem em pontos (concluir, reabrir e
/// excluir passam pelo `ProgressActions`).
class TaskActions {
  TaskActions(this._ref);

  final Ref _ref;

  /// Adia para amanhã, no mesmo horário (só atrasadas e de hoje; ver
  /// [NexoTask.canPostpone]). Devolve a tarefa como era, para o "Desfazer"; `null`
  /// se não dá para adiar.
  Future<NexoTask?> postpone(NexoTask task) async {
    final now = _ref.read(clockProvider)();
    if (!task.canPostpone(now: now)) return null;
    await _ref
        .read(tasksRepositoryProvider)
        .updateTask(
          task.copyWith(dueAt: () => postponedDue(task.dueAt!, now: now)),
        );
    return task;
  }

  /// "Desfazer" do adiar: volta só o prazo antigo, sobre a versão atual da
  /// tarefa (não desfaz uma conclusão feita nesse meio-tempo).
  Future<void> restoreDue(NexoTask original) async {
    final repository = _ref.read(tasksRepositoryProvider);
    final current = (await repository.watchTasks().first)
        .where((t) => t.id == original.id)
        .firstOrNull;
    if (current == null) return;
    await repository.updateTask(current.copyWith(dueAt: () => original.dueAt));
  }
}

final taskActionsProvider = Provider<TaskActions>(TaskActions.new);
