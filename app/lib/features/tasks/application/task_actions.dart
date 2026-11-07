import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../../auth/application/auth_providers.dart';
import '../../progress/application/progress_actions.dart';
import '../domain/task.dart';
import '../domain/task_rules.dart';
import 'tasks_providers.dart';

/// Itens com exclusão pendente: somem da tela na hora e só são apagados de
/// verdade quando a Snackbar com "Desfazer" some sem o toque (design de
/// 04/11/2026: excluir não pede confirmação). Um conjunto por conta: trocar
/// de conta descarta os pendentes.
class PendingDeletions extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(currentUidProvider);
    return const {};
  }

  void add(String id) => state = {...state, id};

  void remove(String id) => state = {...state}..remove(id);
}

/// O que a tela guarda de uma exclusão adiada: o item e a conta em que ela
/// começou.
typedef DeletionReceipt = ({String id, String? uid});

/// Exclusão com "Desfazer": [begin] esconde, [undo] devolve e [finish]
/// apaga. Presa à conta: se ela mudar antes do fim (sair, trocar de conta),
/// nada é apagado nem devolvido na conta nova.
class DeferredDeletion {
  DeferredDeletion(this._ref, this._pending, this._delete);

  final Ref _ref;
  final NotifierProvider<PendingDeletions, Set<String>> _pending;
  final Future<void> Function(String id) _delete;

  bool _sameAccount(DeletionReceipt receipt) =>
      _ref.read(currentUidProvider) == receipt.uid;

  DeletionReceipt begin(String id) {
    _ref.read(_pending.notifier).add(id);
    return (id: id, uid: _ref.read(currentUidProvider));
  }

  void undo(DeletionReceipt receipt) {
    if (_sameAccount(receipt)) _ref.read(_pending.notifier).remove(receipt.id);
  }

  Future<void> finish(DeletionReceipt receipt) async {
    if (!_sameAccount(receipt)) return;
    await _delete(receipt.id);
    if (_sameAccount(receipt)) _ref.read(_pending.notifier).remove(receipt.id);
  }
}

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
