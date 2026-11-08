import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/local_date.dart';
import '../../plans/application/plans_providers.dart';
import '../../progress/application/progress_actions.dart';
import '../../auth/application/deferred_deletion.dart';
import '../domain/goal.dart';
import 'goals_providers.dart';

/// Objetivos com exclusão pendente (somem na hora; o definitivo só quando a
/// Snackbar com "Desfazer" some).
final pendingGoalDeletionsProvider =
    NotifierProvider<PendingDeletions, Set<String>>(PendingDeletions.new);

/// Excluir objetivo com confirmação e "Desfazer" (os planos continuam, sem
/// objetivo).
final goalDeletionProvider = Provider<DeferredDeletion>(
  (ref) => DeferredDeletion(
    ref,
    pendingGoalDeletionsProvider,
    (id) => ref.read(goalActionsProvider).delete(id),
  ),
);

/// Os objetivos sem os de exclusão pendente, em ordem alfabética.
final visibleGoalsProvider = Provider<AsyncValue<List<Goal>>>((ref) {
  final pending = ref.watch(pendingGoalDeletionsProvider);
  return ref
      .watch(goalsProvider)
      .whenData(
        (goals) => [
          for (final g in goals)
            if (!pending.contains(g.id)) g,
        ],
      );
});

/// Criar, editar, excluir e ligar planos a um objetivo.
class GoalActions {
  GoalActions(this._ref);

  final Ref _ref;

  Future<Goal> create({
    required String name,
    String? description,
    LocalDate? deadline,
  }) => _ref
      .read(goalsRepositoryProvider)
      .createGoal(name: name, description: description, deadline: deadline);

  Future<void> update(Goal goal) =>
      _ref.read(goalsRepositoryProvider).updateGoal(goal);

  /// Os planos dele ficam sem objetivo; depois, o objetivo é apagado.
  Future<void> delete(String goalId) async {
    final plans = await _ref.read(plansRepositoryProvider).watchPlans().first;
    final progress = _ref.read(progressActionsProvider);
    for (final plan in plans.where((p) => p.goalId == goalId)) {
      await progress.setPlanGoal(plan.id, null);
    }
    await _ref.read(goalsRepositoryProvider).deleteGoal(goalId);
  }

  /// "Ligar um plano": cada plano marcado passa para este objetivo (um
  /// objetivo por plano). Devolve os objetivos de antes, para o Desfazer.
  Future<Map<String, String?>> linkPlans(
    String goalId,
    Iterable<String> planIds,
  ) async {
    final plans = await _ref.read(plansRepositoryProvider).watchPlans().first;
    final progress = _ref.read(progressActionsProvider);
    final before = <String, String?>{};
    for (final plan in plans.where((p) => planIds.contains(p.id))) {
      before[plan.id] = plan.goalId;
      await progress.setPlanGoal(plan.id, goalId);
    }
    return before;
  }

  /// Desfazer de [linkPlans]: cada plano volta ao objetivo de antes.
  Future<void> restoreGoals(Map<String, String?> before) async {
    final progress = _ref.read(progressActionsProvider);
    for (final entry in before.entries) {
      await progress.setPlanGoal(entry.key, entry.value);
    }
  }
}

final goalActionsProvider = Provider<GoalActions>(GoalActions.new);
