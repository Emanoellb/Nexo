import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/domain/local_date.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../plans/presentation/plan_text.dart';
import '../../subjects/application/subject_actions.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_text.dart';
import '../application/agenda_view.dart';

/// O que o "Reorganizar" devolve: as tarefas marcadas e o dia escolhido.
typedef ReorganizeChoice = ({List<NexoTask> tasks, LocalDate day});

/// "1 tarefa" / "6 tarefas".
String tasksCount(int n) => n == 1 ? '1 tarefa' : '$n tarefas';

/// Reorganizar (Agenda 03): as tarefas pendentes do dia, cada uma com
/// caixa de seleção, o "Mover para" (sugestão: o próximo dia abaixo do
/// limite; os próximos dias com a carga de cada um e "Escolher data…") e
/// "Mover N tarefas". O Nexo sugere e nunca move sozinho.
Future<ReorganizeChoice?> showReorganizeSheet(
  BuildContext context, {
  required AgendaDay day,
  required LocalDate today,
}) => showNexoBottomSheet<ReorganizeChoice>(
  context,
  title: 'Reorganizar ${shortDayText(day.day)}',
  builder: (_) => _ReorganizeForm(day: day, today: today),
);

class _ReorganizeForm extends ConsumerStatefulWidget {
  const _ReorganizeForm({required this.day, required this.today});

  final AgendaDay day;
  final LocalDate today;

  @override
  ConsumerState<_ReorganizeForm> createState() => _ReorganizeFormState();
}

class _ReorganizeFormState extends ConsumerState<_ReorganizeForm> {
  final _chosen = <String>{};
  LocalDate? _target;

  List<NexoTask> get _pending => [
    for (final t in widget.day.tasks)
      if (!t.completed) t,
  ];

  /// "Qui, 13/11 · 1 tarefa": o dia e a carga dele hoje.
  String _option(LocalDate d, Map<LocalDate, int> load) =>
      '${_capitalized(shortDayText(d))} · ${tasksCount(load[d] ?? 0)}';

  static String _capitalized(String s) => s[0].toUpperCase() + s.substring(1);

  Future<void> _pickDay(
    Rect anchor,
    LocalDate suggested,
    Map<LocalDate, int> load,
  ) async {
    var start = widget.day.day.addDays(1);
    if (start.isBefore(widget.today)) start = widget.today;
    final days = [for (var i = 0; i < 7; i++) start.addDays(i)];
    final current = _target ?? suggested;
    final chosen = await showNexoMenu(
      context,
      anchor: anchor,
      label: 'Mover para',
      alignEnd: false,
      items: [
        for (final d in days)
          NexoMenuItem(label: _option(d, load), selected: d == current),
        const NexoMenuItem(label: 'Escolher data…', icon: LucideIcons.calendar),
      ],
    );
    if (chosen == null || !mounted) return;
    if (chosen < days.length) {
      setState(() => _target = days[chosen]);
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: current.startOfDay,
      firstDate: widget.today.startOfDay,
      lastDate: widget.today.addDays(365 * 2).startOfDay,
      helpText: 'Mover para',
    );
    if (picked == null || !mounted) return;
    final day = LocalDate.fromDateTime(picked);
    // O próprio dia não é destino.
    if (day != widget.day.day) setState(() => _target = day);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final load = ref.watch(agendaLoadProvider) ?? const <LocalDate, int>{};
    final suggested = suggestedMoveDay(
      load,
      widget.day.day,
      today: widget.today,
      threshold: widget.day.threshold,
    );
    final target = _target ?? suggested;
    final subjects = {
      for (final s in ref.watch(visibleSubjectsProvider).value ?? const [])
        s.id: s.name,
    };
    final tasks = _pending;
    final count = tasks.where((t) => _chosen.contains(t.id)).length;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Escolha o que pode ir para outro dia.',
            style: textTheme.bodyMedium!.copyWith(color: c.onSurfaceVariant),
          ),
          SizedBox(height: spacing.md),
          for (final t in tasks)
            NexoCheckbox(
              key: ValueKey(t.id),
              value: _chosen.contains(t.id),
              labelText: t.title,
              helperText: [
                if (subjects[t.subjectId] != null) subjects[t.subjectId]!,
                hhmm(t.dueAt!),
              ].join(' · '),
              onChanged: (on) =>
                  setState(() => on ? _chosen.add(t.id) : _chosen.remove(t.id)),
            ),
          SizedBox(height: spacing.md),
          NexoSelectField(
            label: 'Mover para',
            leadingIcon: LucideIcons.calendar,
            value: _option(target, load),
            placeholder: 'Escolha o dia',
            helperText: target == suggested
                ? 'Sugestão: o próximo dia abaixo do seu limite.'
                : null,
            onTap: (anchor) => _pickDay(anchor, suggested, load),
          ),
          SizedBox(height: spacing.lg),
          NexoButton.primary(
            label: count == 0 ? 'Mover tarefas' : 'Mover ${tasksCount(count)}',
            expand: true,
            onPressed: count == 0
                ? null
                : () => Navigator.of(context).pop((
                    tasks: [
                      for (final t in tasks)
                        if (_chosen.contains(t.id)) t,
                    ],
                    day: target,
                  )),
          ),
          SizedBox(height: spacing.lg),
        ],
      ),
    );
  }
}
