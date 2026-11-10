import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/domain/local_date.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../goals/application/goal_actions.dart';
import '../../goals/domain/goal.dart';
import '../../goals/presentation/goal_form.dart';
import '../../tasks/application/screen_now.dart';
import '../application/plans_providers.dart';
import '../domain/plan.dart';
import '../domain/plan_schedule.dart';
import 'plan_form.dart';

/// Editar plano (Planos 20): tela cheia com X. Nome, objetivo, fim, horário
/// e aviso valem na hora; meta e frequência valem a partir de amanhã (nova
/// versão em `scheduleVersions`, RF04). O início fica travado depois de o
/// plano começar.
class EditPlanPage extends ConsumerStatefulWidget {
  const EditPlanPage({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<EditPlanPage> createState() => _EditPlanPageState();
}

class _EditPlanPageState extends ConsumerState<EditPlanPage>
    with LeaveOnce<EditPlanPage> {
  final _name = TextEditingController();
  Plan? _plan;
  late PlanDraft _draft;
  late PlanDraft _initial;
  bool _showErrors = false;
  bool _saving = false;

  LocalDate get _today => LocalDate.fromDateTime(ref.read(screenNowProvider));

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _load(Plan plan) {
    if (_plan != null) return;
    _plan = plan;
    _name.text = plan.name;
    _initial = PlanDraft.of(plan);
    _draft = _initial;
  }

  bool get _started => !_plan!.startDate.isAfter(_today);

  bool get _dirty =>
      _plan != null && (_name.text.trim() != _plan!.name || _draft != _initial);

  Future<void> _close() async {
    if (!_dirty) return leave();
    final discard = await showNexoDiscardDialog(
      context,
      message: 'As mudanças neste plano não serão salvas.',
    );
    if (discard && mounted) leave();
  }

  Future<void> _save() async {
    final plan = _plan!;
    final errors = planBasicsErrors(
      _name.text,
      _draft,
      today: _today,
      creating: !_started && _draft.start != plan.startDate,
    );
    final noDays =
        _draft.kind == FrequencyKind.weekdays && _draft.weekdays.isEmpty;
    if (hasBasicsErrors(errors) || noDays) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    final repository = ref.read(plansRepositoryProvider);
    final draft = _draft;
    final scheduleChanged =
        draft.frequency != plan.frequency ||
        draft.dailyGoalMinutes != plan.dailyGoalMinutes;
    final startChanged = draft.start != plan.startDate;

    await repository.updatePlan(
      plan.copyWith(
        name: _name.text.trim(),
        startDate: draft.start,
        endDate: draft.end,
        goalId: () => draft.goalId,
        studyTime: draft.studyTime,
        reminderBefore: draft.reminderBefore,
      ),
    );
    if (scheduleChanged || startChanged) {
      await repository.addScheduleVersion(
        plan.id,
        ScheduleVersion(
          effectiveFrom: _started
              ? nextEffectiveFrom(today: _today, planStart: draft.start)
              : draft.start,
          frequency: draft.frequency,
          dailyGoalMinutes: draft.dailyGoalMinutes,
        ),
      );
    }
    if (!mounted) return;
    showNexoSnackbar(context, message: 'Alterações salvas.');
    leave();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final plan = ref.watch(planProvider(widget.planId)).value;
    final goals = ref.watch(visibleGoalsProvider).value ?? const <Goal>[];
    final bar = NexoTopAppBar(
      title: 'Editar plano',
      closeIcon: true,
      onBack: _close,
    );
    if (plan == null) {
      return Scaffold(appBar: bar, body: const SizedBox.expand());
    }
    _load(plan);
    final today = LocalDate.fromDateTime(ref.watch(screenNowProvider));
    final errors = _showErrors
        ? planBasicsErrors(
            _name.text,
            _draft,
            today: today,
            creating: !_started && _draft.start != plan.startDate,
          )
        : (name: null, start: null, end: null);

    return PopScope(
      canPop: !_dirty || leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: bar,
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.sm,
            spacing.lg,
            spacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NexoAlert(
                tone: NexoAlertTone.info,
                icon: LucideIcons.info,
                message:
                    'Mudanças na meta e na frequência valem a partir de '
                    'amanhã. Os dias que já passaram não mudam.',
              ),
              SizedBox(height: spacing.lg),
              PlanBasicsFields(
                nameController: _name,
                draft: _draft,
                goals: goals,
                today: today,
                errors: errors,
                startLocked: _started,
                onChanged: (d) => setState(() => _draft = d),
                onNameChanged: () => setState(() {}),
                onNewGoal: () async => (await showGoalForm(context))?.id,
              ),
              SizedBox(height: spacing.xl),
              PlanRhythmFields(
                draft: _draft,
                goalHelper: 'Passos de 15 min.',
                reminderHelper: 'O aviso da manhã fica no Perfil.',
                weekdaysError: _showErrors && _draft.weekdays.isEmpty
                    ? 'Escolha pelo menos um dia.'
                    : null,
                onChanged: (d) => setState(() => _draft = d),
              ),
            ],
          ),
        ),
        // Rodapé no lugar da barra: a Snackbar aparece acima dele e, com o
        // teclado aberto, ele sobe junto (NexoScreenFooter).
        bottomNavigationBar: NexoScreenFooter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.lg,
              spacing.sm,
              spacing.lg,
              spacing.xl,
            ),
            child: NexoButton.primary(
              label: 'Salvar',
              leadingIcon: LucideIcons.check,
              expand: true,
              loading: _saving,
              onPressed: _dirty ? _save : null,
            ),
          ),
        ),
      ),
    );
  }
}
