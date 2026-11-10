import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/format/duration_text.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../plans/domain/plan_day_result.dart';
import '../../plans/presentation/plan_text.dart';
import '../../subjects/application/subject_actions.dart';
import '../../tasks/application/screen_now.dart';
import '../../tasks/application/task_actions.dart';
import '../../tasks/presentation/task_list.dart';
import '../../tasks/presentation/task_text.dart';
import '../application/agenda_view.dart';
import 'reorganize_sheet.dart';

/// Semana (padrão) ou Mês.
enum AgendaMode { week, month }

const _monthNames = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

const _weekdayNames = [
  'segunda',
  'terça',
  'quarta',
  'quinta',
  'sexta',
  'sábado',
  'domingo',
];

String _capitalized(String s) => s[0].toUpperCase() + s.substring(1);

/// "2 a 8 de novembro", "30 de novembro a 6 de dezembro" ou, virando o ano,
/// "28 de dezembro de 2026 a 3 de janeiro de 2027".
String weekRangeText(LocalDate start) {
  final end = start.addDays(6);
  final m1 = _monthNames[start.month - 1];
  final m2 = _monthNames[end.month - 1];
  if (start.year != end.year) {
    return '${start.day} de $m1 de ${start.year} a ${end.day} de $m2 de '
        '${end.year}';
  }
  if (start.month != end.month) {
    return '${start.day} de $m1 a ${end.day} de $m2';
  }
  return '${start.day} a ${end.day} de $m2';
}

/// "Hoje, sex 7 de novembro" ou "Qua, 12 de novembro".
String agendaDayTitle(LocalDate day, LocalDate today) => day == today
    ? 'Hoje, ${weekdayShortLower(day)} ${day.day} de ${_monthNames[day.month - 1]}'
    : dayTitle(day);

/// "2 planos" / "1 plano".
String _plansCount(int n) => n == 1 ? '1 plano' : '$n planos';

/// Agenda (aprovada em 07/11/2026, `pen.dev/notas/agenda-especificacao.md`):
/// Semana (padrão, de domingo a sábado) ou Mês; cada dia com os blocos
/// Planos (com meta no dia; tocar abre o plano) e Tarefas (com prazo no
/// dia; tocar abre a tarefa). Até 3 pontos de carga por dia, só das
/// tarefas pendentes; acima do limite do Perfil, os pontos ficam em
/// Warning e aparece "Dia carregado" com Reorganizar.
class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key});

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage>
    with TaskListActions<AgendaPage>, ScreenNowRefresh<AgendaPage> {
  AgendaMode _mode = AgendaMode.week;
  LocalDate? _selected;

  /// Semana: o domingo. Mês: o dia 1.
  LocalDate? _anchor;

  /// Para onde a troca de período anda: 1 avançar (o novo entra pela
  /// direita) ou −1 voltar.
  int _direction = 1;

  LocalDate get _today => LocalDate.fromDateTime(ref.read(screenNowProvider));

  LocalDate _anchorOf(LocalDate day, AgendaMode mode) => mode == AgendaMode.week
      ? NexoWeek.startOf(day)
      : LocalDate(day.year, day.month, 1);

  void _setMode(AgendaMode mode) {
    if (mode == _mode) return;
    final selected = _selected ?? _today;
    setState(() {
      _mode = mode;
      _anchor = _anchorOf(selected, mode);
    });
  }

  /// As setas: semana ou mês anterior/seguinte. O dia selecionado vai
  /// junto (mesmo dia da semana, ou o dia 1 do mês; hoje, se cair nele).
  void _shift(int step) {
    final anchor = _anchor!;
    final LocalDate next;
    if (_mode == AgendaMode.week) {
      next = anchor.addDays(7 * step);
    } else {
      final m = anchor.month - 1 + step;
      next = LocalDate(anchor.year + (m < 0 ? -1 : m ~/ 12), m % 12 + 1, 1);
    }
    final today = _today;
    final LocalDate selected;
    if (_anchorOf(today, _mode) == next) {
      selected = today;
    } else if (_mode == AgendaMode.week) {
      selected = (_selected ?? today).addDays(7 * step);
    } else {
      selected = next;
    }
    setState(() {
      _direction = step;
      _anchor = next;
      _selected = selected;
    });
  }

  Future<void> _reorganize(AgendaDay day) async {
    final choice = await showReorganizeSheet(context, day: day, today: _today);
    if (choice == null || !mounted) return;
    final actions = ref.read(taskActionsProvider);
    final moved = await actions.moveToDay(choice.tasks, choice.day);
    if (moved.isEmpty || !mounted) return;
    final n = moved.length;
    showNexoSnackbar(
      context,
      message:
          '${n == 1 ? '1 tarefa movida' : '$n tarefas movidas'} para '
          '${shortDayText(choice.day)}.',
      actionLabel: 'Desfazer',
      onAction: () async {
        for (final t in moved) {
          await actions.restoreDue(t);
        }
      },
    );
  }

  /// "Quarta, 12 de novembro, 6 tarefas, sobrecarregado, hoje".
  String _dayLabel(LocalDate day, int pending, bool overloaded) => [
    '${_capitalized(_weekdayNames[day.weekday - 1])}, ${day.day} de '
        '${_monthNames[day.month - 1]}',
    if (overloaded)
      'sobrecarregado: ${tasksCount(pending)}'
    else if (pending > 0)
      tasksCount(pending),
    if (day == _today) 'hoje',
  ].join(', ');

  Widget _dayCell(LocalDate day, Map<LocalDate, int> load, int threshold) {
    final pending = load[day] ?? 0;
    final overloaded = pending > threshold;
    final today = _today;
    return NexoCalendarDay(
      day: day.day,
      below: '',
      loadDots: pending.clamp(0, 3),
      overloaded: overloaded,
      filledSelection: true,
      today: day == today,
      selected: day == _selected,
      semanticsLabel: _dayLabel(day, pending, overloaded),
      onTap: () => setState(() => _selected = day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final now = ref.watch(screenNowProvider);
    final today = LocalDate.fromDateTime(now);
    _selected ??= today;
    _anchor ??= _anchorOf(today, _mode);
    final selected = _selected!;
    final anchor = _anchor!;

    final load = ref.watch(agendaLoadProvider);
    final day = ref.watch(agendaDayProvider(selected));
    final threshold = ref.watch(overloadThresholdProvider);
    final tasks = ref.watch(visibleTasksProvider).value;
    if (tasks != null) scheduleNowRefresh(tasks);

    // A grade usa quase toda a largura (margem XS), como no calendário do
    // plano: em 360 dp, cada dia tem ≥ 48 de largura.
    final inset = EdgeInsets.symmetric(horizontal: spacing.lg - spacing.xs);

    final List<List<LocalDate>> rows;
    if (_mode == AgendaMode.week) {
      rows = [NexoWeek.daysOf(anchor)];
    } else {
      rows = [];
      for (
        var week = NexoWeek.startOf(anchor);
        week.month == anchor.month || week.isBefore(anchor);
        week = week.addDays(7)
      ) {
        rows.add(NexoWeek.daysOf(week));
      }
    }
    final grid = Column(
      key: ValueKey((_mode, anchor)),
      children: [
        for (final week in rows)
          Row(
            children: [
              for (final d in week)
                Expanded(
                  child: _mode == AgendaMode.month && d.month != anchor.month
                      ? const SizedBox.shrink()
                      : _dayCell(d, load ?? const {}, threshold),
                ),
            ],
          ),
      ],
    );

    final reduce = MediaQuery.disableAnimationsOf(context);
    final motion = context.motion;
    // Carrossel (decisão do usuário, 09/11/2026): pelas setas, o período
    // novo entra inteiro pelo lado da seta e o antigo sai inteiro pelo
    // outro, lado a lado e sem esmaecer, em Long · Emphasized. Sem arrastar.
    // A saída usa a curva espelhada para os dois andarem juntos, sem vão
    // nem sobreposição. "Reduzir movimento": corte seco. Semana ↔ Mês não
    // é andar para os lados: cada modo tem o seu carrossel (a chave), e a
    // troca é seca.
    final period = AnimatedSwitcher(
      key: ValueKey(_mode),
      duration: reduce ? Duration.zero : motion.long,
      switchInCurve: motion.emphasized,
      switchOutCurve: motion.emphasized.flipped,
      transitionBuilder: (child, animation) {
        final incoming = child.key == grid.key;
        return SlideTransition(
          position: Tween(
            begin: Offset((incoming ? _direction : -_direction).toDouble(), 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: grid,
    );

    final sections = <Widget>[
      if (day == null)
        const NexoSkeletonList(titleWidth: 96)
      else
        ..._dayContent(day, now, today),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(
        spacing.xs,
        spacing.xs,
        spacing.xs,
        MediaQuery.paddingOf(context).bottom + spacing.xl,
      ),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.lg - spacing.xs,
            0,
            spacing.lg - spacing.xs,
            spacing.sm,
          ),
          child: NexoSegmented<AgendaMode>(
            segments: const [
              (value: AgendaMode.week, label: 'Semana'),
              (value: AgendaMode.month, label: 'Mês'),
            ],
            selected: _mode,
            onChanged: _setMode,
          ),
        ),
        Padding(
          padding: inset,
          child: Row(
            children: [
              NexoIconButton(
                icon: LucideIcons.chevronLeft,
                tooltip: _mode == AgendaMode.week
                    ? 'Semana anterior'
                    : 'Mês anterior',
                color: c.iconDefault,
                onPressed: () => _shift(-1),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    _mode == AgendaMode.week
                        ? weekRangeText(anchor)
                        : monthTitle(anchor.year, anchor.month),
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium!.copyWith(color: c.onSurface),
                  ),
                ),
              ),
              NexoIconButton(
                icon: LucideIcons.chevronRight,
                tooltip: _mode == AgendaMode.week
                    ? 'Próxima semana'
                    : 'Próximo mês',
                color: c.iconDefault,
                onPressed: () => _shift(1),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.sm),
        ExcludeSemantics(
          child: Row(
            children: [
              for (final d in weekdayInitials)
                Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall!.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: spacing.xs),
        ClipRect(child: period),
        SizedBox(height: spacing.lg),
        Padding(
          padding: inset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  agendaDayTitle(selected, today),
                  style: textTheme.titleMedium!.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              ),
              for (final s in sections) ...[SizedBox(height: spacing.lg), s],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _dayContent(AgendaDay day, DateTime now, LocalDate today) {
    final subjects = {
      for (final s in ref.watch(visibleSubjectsProvider).value ?? const [])
        s.id: s.name,
    };
    if (day.isEmpty) {
      final rest = day.restPlans;
      return [
        NexoCardList(
          children: [
            NexoEmptyState(
              icon: LucideIcons.calendar,
              title: 'Nada marcado para este dia',
              message: rest.isEmpty
                  ? 'As tarefas com prazo e os planos com meta neste dia '
                        'aparecem aqui.'
                  : 'Folga do plano ${rest.map((p) => p.name).join(', ')}. '
                        'Aproveite para descansar.',
              actionLabel: day.day.isBefore(today) ? null : 'Criar uma tarefa',
              actionIcon: LucideIcons.plus,
              onAction: () => context.push(AppRoutes.newTask),
            ),
          ],
        ),
      ];
    }
    return [
      // Sobrecarga: só de hoje em diante (não dá para reorganizar o
      // passado).
      if (day.overloaded && !day.day.isBefore(today))
        NexoAlert(
          tone: NexoAlertTone.warning,
          icon: LucideIcons.triangleAlert,
          title: 'Dia carregado',
          message:
              '${tasksCount(day.pending)} neste dia. Seu limite é '
              '${day.threshold}.',
          actionLabel: 'Reorganizar',
          onAction: () => _reorganize(day),
        ),
      if (day.plans.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NexoListHeader(
              title: 'Planos',
              count: _plansCount(day.plans.length),
              indented: false,
            ),
            NexoCardList(
              children: [
                for (final p in day.plans)
                  NexoListItem(
                    key: ValueKey(p.plan.id),
                    icon: LucideIcons.target,
                    title: p.plan.name,
                    supporting: _planLine(p, today),
                    onTap: () =>
                        context.push(AppRoutes.planDetailOf(p.plan.id)),
                  ),
              ],
            ),
          ],
        ),
      if (day.tasks.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NexoListHeader(
              title: 'Tarefas',
              count: tasksCount(day.tasks.length),
              indented: false,
            ),
            NexoCardList(
              children: [
                for (final t in day.tasks)
                  NexoTaskItem(
                    key: ValueKey(t.id),
                    title: t.title,
                    completed: t.completed,
                    onCompletedChanged: (v) => setTaskCompleted(t, v),
                    subject: subjects[t.subjectId],
                    deadline: deadlineFor(
                      t.dueAt!,
                      now,
                      completed: t.completed,
                    ),
                    onTap: () => openTask(t),
                  ),
              ],
            ),
          ],
        ),
    ];
  }

  /// "19:00 · meta 1h 30min · 1h 10min feitos" (sem o feito nos dias que
  /// ainda não chegaram).
  String _planLine(AgendaPlan p, LocalDate today) {
    final r = p.result;
    return [
      p.plan.studyTime,
      'meta ${formatMinutes(r.goalMinutes)}',
      if (!r.day.isAfter(today) &&
          (r.doneMinutes > 0 || r.status != PlanDayStatus.inProgress))
        '${formatMinutes(r.doneMinutes)} feitos',
    ].join(' · ');
  }
}
