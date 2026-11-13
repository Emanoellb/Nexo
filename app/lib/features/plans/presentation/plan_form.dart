import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/domain/edit_window.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../goals/domain/goal.dart';
import '../../notifications/application/local_notices.dart';
import '../../../core/format/duration_text.dart';
import '../../tasks/presentation/task_text.dart';
import '../domain/plan.dart';
import '../domain/plan_schedule.dart';
import 'plan_text.dart';

/// Tipo de frequência no segmentado.
enum FrequencyKind {
  daily('Todos os dias'),
  weekdays('Dias da semana'),
  timesPerWeek('× por semana');

  const FrequencyKind(this.label);

  final String label;
}

/// O que o Criar plano e o Editar plano editam.
@immutable
class PlanDraft {
  const PlanDraft({
    required this.goalId,
    required this.start,
    required this.end,
    required this.kind,
    required this.weekdays,
    required this.timesPerWeek,
    required this.dailyGoalMinutes,
    required this.studyTime,
    required this.reminderEnabled,
    required this.minutesBefore,
  });

  /// Padrões do Criar plano: hoje, todos os dias, 1h por dia, 19:00 e aviso
  /// 15 min antes (v0.9).
  factory PlanDraft.initial(LocalDate today) => PlanDraft(
    goalId: null,
    start: today,
    end: null,
    kind: FrequencyKind.daily,
    weekdays: const {1, 2, 3, 4, 5},
    timesPerWeek: 3,
    dailyGoalMinutes: 60,
    studyTime: Plan.defaultStudyTime,
    reminderEnabled: true,
    minutesBefore: 15,
  );

  factory PlanDraft.of(Plan plan) {
    final f = plan.frequency;
    return PlanDraft(
      goalId: plan.goalId,
      start: plan.startDate,
      end: plan.endDate,
      kind: switch (f) {
        DailyFrequency() => FrequencyKind.daily,
        WeekdaysFrequency() => FrequencyKind.weekdays,
        TimesPerWeekFrequency() => FrequencyKind.timesPerWeek,
      },
      weekdays: f is WeekdaysFrequency ? f.weekdays : const {1, 2, 3, 4, 5},
      timesPerWeek: f is TimesPerWeekFrequency ? f.timesPerWeek : 3,
      dailyGoalMinutes: plan.dailyGoalMinutes,
      studyTime: plan.studyTime,
      reminderEnabled: plan.reminderBefore.enabled,
      minutesBefore: plan.reminderBefore.minutesBefore,
    );
  }

  final String? goalId;
  final LocalDate start;
  final LocalDate? end;
  final FrequencyKind kind;
  final Set<int> weekdays;
  final int timesPerWeek;
  final int dailyGoalMinutes;
  final String studyTime;
  final bool reminderEnabled;
  final int minutesBefore;

  /// Passo da meta diária.
  static const goalStep = 15;

  PlanFrequency get frequency => switch (kind) {
    FrequencyKind.daily => const DailyFrequency(),
    FrequencyKind.weekdays => WeekdaysFrequency(weekdays),
    FrequencyKind.timesPerWeek => TimesPerWeekFrequency(timesPerWeek),
  };

  PlanReminderBefore get reminderBefore => PlanReminderBefore(
    enabled: reminderEnabled,
    minutesBefore: minutesBefore,
  );

  PlanDraft copyWith({
    String? Function()? goalId,
    LocalDate? start,
    LocalDate? Function()? end,
    FrequencyKind? kind,
    Set<int>? weekdays,
    int? timesPerWeek,
    int? dailyGoalMinutes,
    String? studyTime,
    bool? reminderEnabled,
    int? minutesBefore,
  }) => PlanDraft(
    goalId: goalId == null ? this.goalId : goalId(),
    start: start ?? this.start,
    end: end == null ? this.end : end(),
    kind: kind ?? this.kind,
    weekdays: weekdays ?? this.weekdays,
    timesPerWeek: timesPerWeek ?? this.timesPerWeek,
    dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
    studyTime: studyTime ?? this.studyTime,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    minutesBefore: minutesBefore ?? this.minutesBefore,
  );

  @override
  bool operator ==(Object other) =>
      other is PlanDraft &&
      other.goalId == goalId &&
      other.start == start &&
      other.end == end &&
      other.kind == kind &&
      _sameSet(other.weekdays, weekdays) &&
      other.timesPerWeek == timesPerWeek &&
      other.dailyGoalMinutes == dailyGoalMinutes &&
      other.studyTime == studyTime &&
      other.reminderEnabled == reminderEnabled &&
      other.minutesBefore == minutesBefore;

  static bool _sameSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  int get hashCode => Object.hash(
    goalId,
    start,
    end,
    kind,
    Object.hashAllUnordered(weekdays),
    timesPerWeek,
    dailyGoalMinutes,
    studyTime,
    reminderEnabled,
    minutesBefore,
  );
}

/// Erros do passo 1 (e do Editar plano), por campo.
typedef PlanBasicsErrors = ({String? name, String? start, String? end});

/// Valida nome e período pelas regras: início até 7 dias atrás (só ao
/// criar), fim depois do início e período de até 2 anos.
PlanBasicsErrors planBasicsErrors(
  String name,
  PlanDraft draft, {
  required LocalDate today,
  bool creating = true,
}) {
  String? start;
  // Até 7 dias para trás; para frente, livre.
  if (creating && draft.start.isBefore(today.addDays(-editWindowDays))) {
    start = 'O início pode ser até 7 dias atrás.';
  }
  final end = draft.end;
  String? endError;
  if (end == null) {
    endError = 'Escolha o fim do plano.';
  } else if (!end.isAfter(draft.start)) {
    endError = 'O fim precisa ser depois do início.';
  } else if (draft.start.daysUntil(end) > Plan.maxPeriodDays) {
    endError = 'O período vai até 2 anos.';
  }
  return (
    name: name.trim().isEmpty ? 'Dê um nome ao plano.' : null,
    start: start,
    end: endError,
  );
}

bool hasBasicsErrors(PlanBasicsErrors e) =>
    e.name != null || e.start != null || e.end != null;

String _dateText(LocalDate day, LocalDate today) =>
    dueDateFieldText(day, today);

/// Passo 1 · O plano (e o topo do Editar plano): nome, objetivo e período.
class PlanBasicsFields extends StatelessWidget {
  const PlanBasicsFields({
    super.key,
    required this.nameController,
    required this.draft,
    required this.goals,
    required this.today,
    required this.errors,
    required this.onChanged,
    required this.onNameChanged,
    required this.onNewGoal,
    this.startLocked = false,
  });

  final TextEditingController nameController;
  final PlanDraft draft;
  final List<Goal> goals;
  final LocalDate today;
  final PlanBasicsErrors errors;
  final ValueChanged<PlanDraft> onChanged;
  final VoidCallback onNameChanged;

  /// "Novo objetivo…": abre o painel e devolve o id criado.
  final Future<String?> Function() onNewGoal;

  /// Editar plano: o início fica travado depois de começar.
  final bool startLocked;

  Future<void> _pickGoal(BuildContext context, Rect anchor) async {
    final chosen = await showNexoMenu(
      context,
      anchor: anchor,
      label: 'Objetivo',
      alignEnd: false,
      items: [
        NexoMenuItem(label: 'Sem objetivo', selected: draft.goalId == null),
        for (final g in goals)
          NexoMenuItem(label: g.name, selected: g.id == draft.goalId),
        const NexoMenuItem(label: 'Novo objetivo…', icon: LucideIcons.plus),
      ],
    );
    if (chosen == null) return;
    if (chosen == 0) {
      onChanged(draft.copyWith(goalId: () => null));
    } else if (chosen <= goals.length) {
      onChanged(draft.copyWith(goalId: () => goals[chosen - 1].id));
    } else {
      final id = await onNewGoal();
      if (id != null) onChanged(draft.copyWith(goalId: () => id));
    }
  }

  Future<void> _pickDate(BuildContext context, {required bool isStart}) async {
    final current = isStart ? draft.start : (draft.end ?? draft.start);
    final first = isStart ? today.addDays(-7) : draft.start.addDays(1);
    final last = isStart
        ? today.addDays(365)
        : draft.start.addDays(Plan.maxPeriodDays);
    var initial = current;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.startOfDay,
      firstDate: first.startOfDay,
      lastDate: last.startOfDay,
      helpText: isStart ? 'Início' : 'Fim',
    );
    if (picked == null) return;
    final day = LocalDate.fromDateTime(picked);
    onChanged(
      isStart ? draft.copyWith(start: day) : draft.copyWith(end: () => day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final c = context.nexoColors;
    final goalName = goals.where((g) => g.id == draft.goalId).firstOrNull?.name;
    final end = draft.end;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NexoTextField(
          label: 'Nome do plano',
          hintText: 'Ex.: Concurso do banco',
          controller: nameController,
          errorText: errors.name,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(80)],
          onChanged: (_) => onNameChanged(),
        ),
        SizedBox(height: spacing.lg),
        NexoSelectField(
          label: 'Objetivo',
          leadingIcon: LucideIcons.flag,
          value: goalName,
          placeholder: 'Sem objetivo',
          helperText: 'Opcional. Agrupa planos com o mesmo fim.',
          onTap: (anchor) => _pickGoal(context, anchor),
        ),
        SizedBox(height: spacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: NexoSelectField(
                label: 'Início',
                trailingIcon: LucideIcons.calendar,
                value: startLocked
                    ? draft.start.toDisplay()
                    : _dateText(draft.start, today),
                placeholder: '',
                errorText: errors.start,
                helperText: startLocked ? 'Já começou' : null,
                onTap: startLocked
                    ? null
                    : (_) => _pickDate(context, isStart: true),
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: NexoSelectField(
                label: 'Fim',
                trailingIcon: LucideIcons.calendar,
                value: end == null
                    ? null
                    : startLocked
                    ? end.toDisplay()
                    : _dateText(end, today),
                placeholder: 'Escolher',
                errorText: errors.end,
                onTap: (_) => _pickDate(context, isStart: false),
              ),
            ),
          ],
        ),
        if (!startLocked) ...[
          SizedBox(height: spacing.sm),
          Text(
            'Até 2 anos. O início pode ser até 7 dias atrás.',
            style: Theme.of(context).textTheme.bodySmall!
                .copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Passo 2 · Ritmo (e o meio do Editar plano): frequência, dias ou cota,
/// meta diária, horário do plano e o aviso antes do horário.
class PlanRhythmFields extends StatelessWidget {
  const PlanRhythmFields({
    super.key,
    required this.draft,
    required this.onChanged,
    this.goalHelper =
        'Passos de 15 min. Mudar depois vale a partir do dia seguinte.',
    this.reminderHelper =
        'O aviso da manhã, com o resumo do dia, fica no Perfil.',
    this.weekdaysError,
  });

  final PlanDraft draft;
  final ValueChanged<PlanDraft> onChanged;
  final String goalHelper;
  final String reminderHelper;
  final String? weekdaysError;

  Future<void> _pickTime(BuildContext context) async {
    final parts = draft.studyTime.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
      helpText: 'Horário do plano',
    );
    if (picked == null) return;
    String two(int n) => n.toString().padLeft(2, '0');
    onChanged(
      draft.copyWith(studyTime: '${two(picked.hour)}:${two(picked.minute)}'),
    );
  }

  Future<void> _pickBefore(BuildContext context, Rect anchor) async {
    const options = PlanReminderBefore.options;
    final chosen = await showNexoMenu(
      context,
      anchor: anchor,
      label: 'Antecedência',
      alignEnd: false,
      items: [
        for (final m in options)
          NexoMenuItem(
            label: reminderBeforeLabel(m),
            selected: m == draft.minutesBefore,
          ),
      ],
    );
    if (chosen != null) {
      onChanged(draft.copyWith(minutesBefore: options[chosen]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    Widget label(String text) => Semantics(
      header: true,
      child: Text(
        text,
        style: textTheme.labelMedium!.copyWith(color: c.onSurface),
      ),
    );
    final goal = draft.dailyGoalMinutes;
    final times = draft.timesPerWeek;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label('Frequência'),
        SizedBox(height: spacing.sm),
        Semantics(
          label: 'Frequência',
          container: true,
          child: NexoSegmented<FrequencyKind>(
            segments: [
              for (final k in FrequencyKind.values) (value: k, label: k.label),
            ],
            selected: draft.kind,
            onChanged: (k) => onChanged(draft.copyWith(kind: k)),
          ),
        ),
        if (draft.kind == FrequencyKind.weekdays) ...[
          SizedBox(height: spacing.sm),
          _WeekdayPicker(
            selected: draft.weekdays,
            onChanged: (days) => onChanged(draft.copyWith(weekdays: days)),
          ),
          if (weekdaysError != null) ...[
            SizedBox(height: spacing.xs),
            Semantics(
              liveRegion: true,
              child: Text(
                weekdaysError!,
                style: textTheme.bodySmall!.copyWith(color: c.error),
              ),
            ),
          ],
        ],
        if (draft.kind == FrequencyKind.timesPerWeek) ...[
          SizedBox(height: spacing.sm),
          NexoStepper(
            label: 'Vezes por semana',
            valueText: '$times ${times == 1 ? 'vez' : 'vezes'} por semana',
            onDecrement: times > 1
                ? () => onChanged(draft.copyWith(timesPerWeek: times - 1))
                : null,
            onIncrement: times < 7
                ? () => onChanged(draft.copyWith(timesPerWeek: times + 1))
                : null,
            helper:
                'Semana de domingo a sábado. Depois de $times '
                '${times == 1 ? 'dia' : 'dias'} com atividade, o resto da '
                'semana é folga.',
          ),
        ],
        SizedBox(height: spacing.lg),
        label('Meta diária'),
        SizedBox(height: spacing.sm),
        NexoStepper(
          label: 'Meta diária',
          valueText: formatMinutes(goal),
          onDecrement: goal > PlanDraft.goalStep
              ? () => onChanged(
                  draft.copyWith(dailyGoalMinutes: goal - PlanDraft.goalStep),
                )
              : null,
          onIncrement: goal + PlanDraft.goalStep <= 1440
              ? () => onChanged(
                  draft.copyWith(dailyGoalMinutes: goal + PlanDraft.goalStep),
                )
              : null,
          helper: goalHelper,
        ),
        SizedBox(height: spacing.lg),
        NexoSelectField(
          label: 'Horário do plano',
          trailingIcon: LucideIcons.clock3,
          value: draft.studyTime,
          placeholder: Plan.defaultStudyTime,
          helperText: 'Quando você costuma se dedicar a este plano.',
          onTap: (_) => _pickTime(context),
        ),
        SizedBox(height: spacing.md),
        NexoSwitch(
          label: 'Avisar antes do horário',
          helper: reminderHelper,
          value: draft.reminderEnabled,
          onChanged: (v) {
            // Ligar o aviso pede a permissão de notificações (Android 13+).
            if (v) {
              unawaited(
                ProviderScope.containerOf(context)
                    .read(notificationsAllowedProvider.notifier)
                    .request(),
              );
            }
            onChanged(draft.copyWith(reminderEnabled: v));
          },
        ),
        if (draft.reminderEnabled) ...[
          SizedBox(height: spacing.md),
          NexoSelectField(
            label: 'Antecedência',
            leadingIcon: LucideIcons.bell,
            value: reminderBeforeLabel(draft.minutesBefore),
            placeholder: '',
            onTap: (anchor) => _pickBefore(context, anchor),
          ),
        ],
      ],
    );
  }
}

/// Seletor de dias D S T Q Q S S (domingo a sábado): o marcado em Primary
/// com o texto em OnPrimary; os outros em SurfaceContainer. Cada dia tem o
/// alvo de 48 × 48 (decisão travada): se os 7 não cabem numa linha (telas
/// estreitas, ~360 dp), vão para duas linhas. O leitor de tela lê o nome
/// do dia e se está marcado.
class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onChanged});

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  Widget _day(int i, {double? width}) {
    final day = weekdayOrder[i];
    final on = selected.contains(day);
    return NexoDayChip(
      label: weekdayInitials[i],
      semanticsLabel: weekdayName(day),
      selected: on,
      width: width,
      onChanged: (_) =>
          onChanged(on ? ({...selected}..remove(day)) : {...selected, day}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final target = context.sizes.target;
    return LayoutBuilder(
      builder: (context, constraints) {
        final fits = constraints.maxWidth >= 7 * target + 6 * spacing.xs;
        if (fits) {
          return Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) SizedBox(width: spacing.xs),
                Expanded(child: _day(i)),
              ],
            ],
          );
        }
        return Wrap(
          spacing: spacing.xs,
          children: [for (var i = 0; i < 7; i++) _day(i, width: target)],
        );
      },
    );
  }
}
