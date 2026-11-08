import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../auth/application/auth_providers.dart';
import '../../plans/application/plan_today.dart';
import '../../plans/application/plans_providers.dart';
import '../../plans/presentation/plan_list_item.dart';
import '../../plans/domain/plan.dart';
import '../../plans/presentation/plan_menu.dart';
import '../../plans/presentation/plan_row.dart';
import '../../plans/presentation/plan_text.dart';
import '../../tasks/application/screen_now.dart';
import '../../auth/presentation/deferred_deletion_snackbar.dart';
import '../application/goal_actions.dart';
import '../domain/goal.dart';
import 'goal_form.dart';

/// Detalhe do objetivo (Planos 11–14), dentro da aba Planos: descrição,
/// prazo, os planos ligados (recolhível) e "Ligar um plano". O lápis edita;
/// o ⋯ exclui (confirma; os planos ficam sem objetivo; Desfazer).
class GoalDetailPage extends ConsumerStatefulWidget {
  const GoalDetailPage({super.key, required this.goalId});

  final String goalId;

  @override
  ConsumerState<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends ConsumerState<GoalDetailPage>
    with LeaveOnce<GoalDetailPage> {
  final _moreKey = GlobalKey();
  bool _expanded = true;

  Future<void> _delete(Goal goal) async {
    final confirmed = await showNexoDialog(
      context,
      title: 'Excluir objetivo?',
      message:
          '“${goal.name}” sai da sua lista. Os planos dele continuam, sem '
          'objetivo.',
      confirmLabel: 'Excluir objetivo',
      icon: LucideIcons.trash2,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    ref
        .read(goalDeletionProvider)
        .withUndo(context, goal.id, message: 'Objetivo excluído.');
    leave();
  }

  Future<void> _more(Goal goal) async {
    final box = _moreKey.currentContext!.findRenderObject()! as RenderBox;
    final chosen = await showNexoMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      label: 'Mais opções',
      items: const [
        NexoMenuItem(label: 'Editar objetivo', icon: LucideIcons.pencil),
        NexoMenuItem(
          label: 'Excluir objetivo',
          icon: LucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (!mounted) return;
    switch (chosen) {
      case 0:
        await showGoalForm(context, editing: goal);
      case 1:
        await _delete(goal);
    }
  }

  Future<void> _link(Goal goal, List<Plan> plans) async {
    final candidates = [
      for (final p in plans)
        if (p.goalId != goal.id && p.status != PlanStatus.archived) p,
    ];
    final goals = {
      for (final g in ref.read(visibleGoalsProvider).value ?? const <Goal>[])
        g.id: g.name,
    };
    final today = LocalDate.fromDateTime(ref.read(screenNowProvider));
    final chosen = await showNexoBottomSheet<Set<String>>(
      context,
      title: 'Ligar planos a este objetivo',
      builder: (_) =>
          _LinkPlansForm(plans: candidates, goalNames: goals, today: today),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    final actions = ref.read(goalActionsProvider);
    final before = await actions.linkPlans(goal.id, chosen);
    if (!mounted) return;
    showNexoSnackbar(
      context,
      message: chosen.length == 1 ? 'Plano ligado.' : 'Planos ligados.',
      actionLabel: 'Desfazer',
      onAction: () => actions.restoreGoals(before),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final goals = ref.watch(visibleGoalsProvider);
    final goal = goals.value?.where((g) => g.id == widget.goalId).firstOrNull;
    if (goals.hasValue && goal == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) leave();
      });
    }

    final bar = NexoTopAppBar(
      title: goal?.name ?? '',
      onBack: leave,
      actions: [
        NexoIconButton(
          icon: LucideIcons.pencil,
          tooltip: 'Editar objetivo',
          color: c.iconDefault,
          onPressed: goal == null
              ? null
              : () => showGoalForm(context, editing: goal),
        ),
        NexoIconButton(
          key: _moreKey,
          icon: LucideIcons.ellipsis,
          tooltip: 'Mais opções',
          color: c.iconDefault,
          onPressed: goal == null ? null : () => _more(goal),
        ),
      ],
    );
    final plans = ref.watch(plansProvider).value;
    if (goal == null || plans == null) {
      return Scaffold(appBar: bar, body: const SizedBox.expand());
    }

    final today = LocalDate.fromDateTime(ref.watch(screenNowProvider));
    final primaryId = ref.watch(userProfileProvider).value?.primaryPlanId;
    final linked = [
      for (final p in plans)
        if (p.goalId == goal.id) p,
    ];
    final textTheme = Theme.of(context).textTheme;
    final deadline = goalDeadlineLong(goal.deadline);

    return Scaffold(
      appBar: bar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          spacing.lg,
          spacing.sm,
          spacing.lg,
          MediaQuery.paddingOf(context).bottom + spacing.xl,
        ),
        children: [
          if (goal.description != null) ...[
            Text(
              goal.description!,
              style: textTheme.bodyMedium!.copyWith(color: c.onSurface),
            ),
            SizedBox(height: spacing.sm),
          ],
          Text(
            deadline ?? 'Sem prazo',
            style: textTheme.labelSmall!.copyWith(color: c.onSurfaceVariant),
          ),
          SizedBox(height: spacing.lg),
          NexoSectionHeader(
            title: 'Planos ligados',
            count: linked.length,
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            NexoCardList(
              children: [
                for (final plan in linked)
                  if (ref.watch(planSnapshotProvider(plan.id))
                      case final snapshot?)
                    PlanRow(
                      key: ValueKey(plan.id),
                      item: planListItem(snapshot, today: today),
                      onTap: () =>
                          context.push(AppRoutes.planDetailOf(plan.id)),
                      onLongPress: (anchor) => showPlanMenu(
                        context,
                        ref,
                        plan: plan,
                        anchor: anchor,
                        isPrimary: plan.id == primaryId,
                        includeUnlink: true,
                      ),
                    ),
                NexoAddRow(
                  label: 'Ligar um plano',
                  icon: LucideIcons.link,
                  onTap: () => _link(goal, plans),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// "Ligar planos a este objetivo" (Planos 13): seleção múltipla. Um plano
/// de outro objetivo mostra "Hoje em: …" e muda para este.
class _LinkPlansForm extends StatefulWidget {
  const _LinkPlansForm({
    required this.plans,
    required this.goalNames,
    required this.today,
  });

  final List<Plan> plans;
  final Map<String, String> goalNames;
  final LocalDate today;

  @override
  State<_LinkPlansForm> createState() => _LinkPlansFormState();
}

class _LinkPlansFormState extends State<_LinkPlansForm> {
  final _selected = <String>{};

  String _supporting(Plan plan) {
    final goal = widget.goalNames[plan.goalId];
    if (goal != null) return 'Hoje em: $goal';
    final status = switch (plan.status) {
      PlanStatus.paused => 'Pausado',
      PlanStatus.completed || PlanStatus.endedEarly => 'Encerrado',
      _ => 'Ativo',
    };
    return '$status · sem objetivo';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final n = _selected.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.plans.isEmpty)
          Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: Text(
              'Todos os seus planos já estão neste objetivo.',
              style: Theme.of(context).textTheme.bodyMedium!
                  .copyWith(color: c.onSurfaceVariant),
            ),
          ),
        for (final plan in widget.plans)
          NexoListItem(
            key: ValueKey(plan.id),
            icon: LucideIcons.target,
            title: plan.name,
            supporting: _supporting(plan),
            selected: _selected.contains(plan.id),
            trailing: NexoCheckbox(
              value: _selected.contains(plan.id),
              onChanged: (_) => setState(() {
                if (!_selected.remove(plan.id)) _selected.add(plan.id);
              }),
              semanticLabel: plan.name,
            ),
            onTap: () => setState(() {
              if (!_selected.remove(plan.id)) _selected.add(plan.id);
            }),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(spacing.lg, spacing.md, spacing.lg, 0),
          child: Text(
            'Cada plano fica em um objetivo só. Marcar um plano que já está '
            'em outro objetivo muda ele para este.',
            style: Theme.of(context).textTheme.bodySmall!
                .copyWith(color: c.onSurfaceVariant),
          ),
        ),
        SizedBox(height: spacing.lg),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.lg),
          child: NexoButton.primary(
            label: n <= 1 ? 'Ligar $n plano' : 'Ligar $n planos',
            leadingIcon: LucideIcons.link,
            expand: true,
            onPressed: n == 0
                ? null
                : () => Navigator.of(context).pop(Set.of(_selected)),
          ),
        ),
      ],
    );
  }
}
