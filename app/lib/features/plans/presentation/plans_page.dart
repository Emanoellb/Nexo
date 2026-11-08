import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../auth/application/auth_providers.dart';
import '../../goals/presentation/goals_view.dart';
import '../../tasks/application/screen_now.dart';
import '../application/plans_view.dart';
import 'plan_list_item.dart';
import 'plan_menu.dart';
import 'plan_row.dart';

/// O que o segmentado do topo mostra.
enum PlansSegment { plans, goals }

/// Planos (aba 3), aprovada no Pen.dev em 07/11/2026 (Seção / Planos e
/// Objetivos). Segmentado "Planos | Objetivos", igual a Tarefas |
/// Disciplinas. Planos por status, com o principal no topo (Miller: até 4
/// grupos abertos, 3 informações por plano); Concluídos e Arquivados
/// começam recolhidos. Toque abre o plano; toque longo, o menu dele.
class PlansPage extends ConsumerStatefulWidget {
  const PlansPage({super.key});

  @override
  ConsumerState<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends ConsumerState<PlansPage>
    with NexoDelayedSkeleton<PlansPage> {
  PlansSegment _segment = PlansSegment.plans;
  final _collapsed = <PlanGroup>{
    for (final g in PlanGroup.values)
      if (g.startsCollapsed) g,
  };

  void _toggle(PlanGroup group) => setState(() {
    if (!_collapsed.remove(group)) _collapsed.add(group);
  });

  void _create() => context.push(AppRoutes.newPlan);

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.xs,
            spacing.lg,
            spacing.sm,
          ),
          child: NexoSegmented<PlansSegment>(
            segments: const [
              (value: PlansSegment.plans, label: 'Planos'),
              (value: PlansSegment.goals, label: 'Objetivos'),
            ],
            selected: _segment,
            onChanged: (value) => setState(() => _segment = value),
          ),
        ),
        Expanded(
          child: switch (_segment) {
            PlansSegment.plans => _plans(),
            PlansSegment.goals => const GoalsView(),
          },
        ),
      ],
    );
  }

  Widget _plans() {
    final groups = ref.watch(planListProvider);
    if (groups == null) {
      return whileLoading(
        Padding(
          padding: EdgeInsets.all(context.spacing.lg),
          child: const NexoSkeletonList(titleWidth: 120),
        ),
      );
    }
    loaded();
    final spacing = context.spacing;
    final primaryId = ref.watch(userProfileProvider).value?.primaryPlanId;
    final today = LocalDate.fromDateTime(ref.watch(screenNowProvider));
    final bottom = MediaQuery.paddingOf(context).bottom + spacing.xl;

    if (groups.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(
          spacing.lg,
          spacing.xl,
          spacing.lg,
          bottom,
        ),
        children: [
          NexoCardList(
            children: [
              NexoEmptyState(
                icon: LucideIcons.target,
                title: 'Seus planos aparecem aqui',
                message:
                    'Crie um plano com objetivo, período e meta diária. O '
                    'principal aparece no Início.',
                actionLabel: 'Criar um plano',
                actionIcon: LucideIcons.plus,
                onAction: _create,
              ),
            ],
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(spacing.lg, spacing.md, spacing.lg, bottom),
      children: [
        for (final g in groups) ...[
          NexoSectionHeader(
            key: ValueKey(g.group),
            title: g.group.label,
            count: g.plans.length,
            expanded: !_collapsed.contains(g.group),
            onToggle: () => _toggle(g.group),
          ),
          if (!_collapsed.contains(g.group))
            NexoCardList(
              children: [
                for (final item in [
                  for (final s in g.plans) planListItem(s, today: today),
                ])
                  PlanRow(
                    key: ValueKey(item.plan.id),
                    item: item,
                    onTap: () =>
                        context.push(AppRoutes.planDetailOf(item.plan.id)),
                    onLongPress: (anchor) => showPlanMenu(
                      context,
                      ref,
                      plan: item.plan,
                      anchor: anchor,
                      isPrimary: item.plan.id == primaryId,
                    ),
                  ),
              ],
            ),
          SizedBox(height: spacing.md),
        ],
      ],
    );
  }
}
