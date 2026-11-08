import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../plans/application/plans_providers.dart';
import '../../plans/domain/plan.dart';
import '../../plans/presentation/plan_text.dart';
import '../application/goal_actions.dart';
import '../domain/goal.dart';
import 'goal_form.dart';

/// "1 plano · Concurso Banco Horizonte", "2 planos · A, B" ou "Nenhum
/// plano ainda".
String goalPlansLine(List<Plan> plans) => switch (plans.length) {
  0 => 'Nenhum plano ainda',
  1 => '1 plano · ${plans.single.name}',
  final n => '$n planos · ${plans.map((p) => p.name).join(', ')}',
};

/// "Objetivos" no segmentado da aba Planos (Planos 08 e 09): um cartão com
/// uma linha por objetivo (prazo e planos ligados) e "Adicionar objetivo".
class GoalsView extends ConsumerWidget {
  const GoalsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final goals = ref.watch(visibleGoalsProvider);
    final plans = ref.watch(plansProvider);
    if (!goals.hasValue || !plans.hasValue) return const SizedBox.shrink();
    final list = goals.value!;
    void add() => showGoalForm(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        list.isEmpty ? spacing.xl : spacing.md,
        spacing.lg,
        MediaQuery.paddingOf(context).bottom + spacing.xl,
      ),
      children: [
        NexoCardList(
          children: list.isEmpty
              ? [
                  NexoEmptyState(
                    icon: LucideIcons.flag,
                    title: 'Seus objetivos aparecem aqui',
                    message:
                        'Um objetivo junta os planos que levam a ele, como um '
                        'concurso ou um intercâmbio.',
                    actionLabel: 'Criar um objetivo',
                    actionIcon: LucideIcons.plus,
                    onAction: add,
                  ),
                ]
              : [
                  for (final goal in list)
                    _GoalRow(
                      key: ValueKey(goal.id),
                      goal: goal,
                      plans: [
                        for (final p in plans.value!)
                          if (p.goalId == goal.id) p,
                      ],
                    ),
                  NexoAddRow(label: 'Adicionar objetivo', onTap: add),
                ],
        ),
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({super.key, required this.goal, required this.plans});

  final Goal goal;
  final List<Plan> plans;

  @override
  Widget build(BuildContext context) => NexoProgressRow(
    title: goal.name,
    value: goalDeadlineShort(goal.deadline),
    line: goalPlansLine(plans),
    onTap: () => context.push(AppRoutes.goalDetailOf(goal.id)),
  );
}
