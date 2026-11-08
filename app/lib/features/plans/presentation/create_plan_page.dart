import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../goals/application/goal_actions.dart';
import '../../goals/domain/goal.dart';
import '../../goals/presentation/goal_form.dart';
import '../../progress/application/progress_actions.dart';
import '../../subjects/application/subject_actions.dart';
import '../../subjects/domain/subject.dart';
import '../../tasks/application/screen_now.dart';
import '../data/plans_repository.dart';
import '../domain/plan.dart';
import 'plan_form.dart';
import 'plan_text.dart';
import 'topic_sheet.dart';

/// Criar plano (design de Planos 2b, 07/11/2026): tela cheia "Novo plano"
/// com X, em 3 passos curtos (Hick), uma ação principal por passo.
///
/// 1. O plano: nome, objetivo, início e fim.
/// 2. Ritmo: frequência, meta diária, horário do plano e aviso.
/// 3. Tópicos (opcional).
///
/// Ao criar, volta para onde a pessoa estava com "Plano criado." e "Ver".
/// O primeiro plano vira o principal sozinho; [makePrimary] força.
class CreatePlanPage extends ConsumerStatefulWidget {
  const CreatePlanPage({super.key, this.makePrimary = false});

  final bool makePrimary;

  @override
  ConsumerState<CreatePlanPage> createState() => _CreatePlanPageState();
}

class _CreatePlanPageState extends ConsumerState<CreatePlanPage>
    with LeaveOnce<CreatePlanPage> {
  static const _steps = ['O plano', 'Ritmo', 'Tópicos'];

  final _name = TextEditingController();
  late PlanDraft _draft;
  late final PlanDraft _initial;
  final _topics = <NewTopic>[];
  int _step = 0;
  bool _showErrors = false;
  bool _saving = false;

  LocalDate get _today => LocalDate.fromDateTime(ref.read(screenNowProvider));

  @override
  void initState() {
    super.initState();
    _initial = PlanDraft.initial(_today);
    _draft = _initial;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _name.text.trim().isNotEmpty || _draft != _initial || _topics.isNotEmpty;

  Future<void> _close() async {
    if (!_dirty) return leave();
    final discard = await showNexoDiscardDialog(
      context,
      message: 'As informações deste plano não serão salvas.',
    );
    if (discard && mounted) leave();
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      _close();
    }
  }

  void _next() {
    if (_step == 0) {
      final errors = planBasicsErrors(_name.text, _draft, today: _today);
      if (hasBasicsErrors(errors)) {
        setState(() => _showErrors = true);
        return;
      }
    }
    if (_step == 1 &&
        _draft.kind == FrequencyKind.weekdays &&
        _draft.weekdays.isEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _showErrors = false;
      _step++;
    });
  }

  Future<String?> _newGoal() async => (await showGoalForm(context))?.id;

  Future<void> _addTopic() async {
    final result = await showTopicSheet(context);
    if (result == null || result.delete || !mounted) return;
    setState(
      () => _topics.add((name: result.name, subjectId: result.subjectId)),
    );
  }

  Future<void> _create() async {
    if (_saving) return;
    setState(() => _saving = true);
    final progress = ref.read(progressActionsProvider);
    final router = GoRouter.of(context);
    final draft = _draft;
    final plan = await progress.createPlan(
      Plan(
        id: '',
        name: _name.text.trim(),
        startDate: draft.start,
        endDate: draft.end!,
        frequency: draft.frequency,
        dailyGoalMinutes: draft.dailyGoalMinutes,
        goalId: draft.goalId,
        studyTime: draft.studyTime,
        reminderBefore: draft.reminderBefore,
      ),
      topics: List.of(_topics),
      makePrimary: widget.makePrimary,
    );
    if (!mounted) return;
    showNexoSnackbar(
      context,
      message: 'Plano criado.',
      tone: NexoSnackbarTone.success,
      actionLabel: 'Ver',
      onAction: () => router.push(AppRoutes.planDetailOf(plan.id)),
      showClose: true,
      // Na fila: se criar concluir os "Primeiros passos", o aviso do Início
      // vem antes e não é apagado por este.
      queue: true,
    );
    leave();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final goals = ref.watch(visibleGoalsProvider).value ?? const <Goal>[];
    final subjects =
        ref.watch(visibleSubjectsProvider).value ?? const <Subject>[];
    final today = LocalDate.fromDateTime(ref.watch(screenNowProvider));
    final errors = _showErrors
        ? planBasicsErrors(_name.text, _draft, today: today)
        : (name: null, start: null, end: null);

    final Widget content = switch (_step) {
      0 => PlanBasicsFields(
        nameController: _name,
        draft: _draft,
        goals: goals,
        today: today,
        errors: errors,
        onChanged: (d) => setState(() => _draft = d),
        onNameChanged: () => setState(() {}),
        onNewGoal: _newGoal,
      ),
      1 => PlanRhythmFields(
        draft: _draft,
        onChanged: (d) => setState(() => _draft = d),
        weekdaysError: _showErrors && _draft.weekdays.isEmpty
            ? 'Escolha pelo menos um dia.'
            : null,
      ),
      _ => _TopicsStep(
        topics: _topics,
        subjects: subjects,
        onAdd: _addTopic,
        onRemove: (i) => setState(() => _topics.removeAt(i)),
      ),
    };

    final last = _step == _steps.length - 1;
    final NexoButton primary = last
        ? NexoButton.primary(
            label: 'Criar plano',
            leadingIcon: LucideIcons.check,
            loading: _saving,
            onPressed: _create,
          )
        : NexoButton.primary(
            label: 'Continuar',
            trailingIcon: LucideIcons.arrowRight,
            onPressed: _next,
          );

    return PopScope(
      canPop: leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: NexoTopAppBar(
          title: 'Novo plano',
          closeIcon: true,
          onBack: _close,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.lg),
              child: Row(
                children: [
                  NexoPageControl(count: _steps.length, index: _step),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        'Passo ${_step + 1} de ${_steps.length} · '
                        '${_steps[_step]}',
                        style: Theme.of(context).textTheme.labelSmall!
                            .copyWith(color: c.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey(_step),
                padding: EdgeInsets.fromLTRB(
                  spacing.lg,
                  spacing.md,
                  spacing.lg,
                  spacing.lg,
                ),
                child: content,
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.lg,
                  spacing.sm,
                  spacing.lg,
                  spacing.xl,
                ),
                child: _Footer(
                  back: _step > 0
                      ? NexoButton.tertiary(
                          label: 'Voltar',
                          leadingIcon: LucideIcons.arrowLeft,
                          onPressed: _back,
                        )
                      : null,
                  primary: primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rodapé dos passos: "Voltar" (Tertiary) à esquerda e a ação principal à
/// direita. Com fonte ampliada, os dois não cabem lado a lado sem espremer
/// a principal: empilham, com a principal em cima, na largura toda.
class _Footer extends StatelessWidget {
  const _Footer({required this.back, required this.primary});

  final Widget? back;
  final NexoButton primary;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          if (back != null) ...[SizedBox(height: spacing.sm), back!],
        ],
      );
    }
    return Row(
      children: [
        ?back,
        SizedBox(width: spacing.sm),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: primary,
          ),
        ),
      ],
    );
  }
}

/// Passo 3 · Tópicos (opcional): ajuda, o cartão com os tópicos (X tira) e
/// "Adicionar tópico".
class _TopicsStep extends StatelessWidget {
  const _TopicsStep({
    required this.topics,
    required this.subjects,
    required this.onAdd,
    required this.onRemove,
  });

  final List<NewTopic> topics;
  final List<Subject> subjects;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Opcional. Os tópicos marcam o que você fez em cada sessão de '
          'foco. Dá para adicionar depois.',
          style: Theme.of(context).textTheme.bodyMedium!
              .copyWith(color: c.onSurfaceVariant),
        ),
        SizedBox(height: spacing.md),
        NexoCardList(
          children: [
            for (var i = 0; i < topics.length; i++)
              NexoListItem(
                key: ValueKey('topic-$i-${topics[i].name}'),
                icon: LucideIcons.bookmark,
                title: topics[i].name,
                supporting: topicSupporting(topics[i].subjectId, subjects),
                trailing: NexoIconButton(
                  icon: LucideIcons.x,
                  tooltip: 'Tirar ${topics[i].name}',
                  iconSize: 20,
                  onPressed: () => onRemove(i),
                ),
              ),
            NexoAddRow(label: 'Adicionar tópico', onTap: onAdd),
          ],
        ),
      ],
    );
  }
}
