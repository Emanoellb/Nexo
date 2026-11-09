import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/domain/edit_window.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../auth/application/auth_providers.dart';
import '../../focus/domain/focus_session.dart';
import '../../goals/application/goal_actions.dart';
import '../../../core/format/duration_text.dart';
import '../../progress/application/progress_actions.dart';
import '../../subjects/application/subject_actions.dart';
import '../../subjects/domain/subject.dart';
import '../../tasks/application/screen_now.dart';
import '../../auth/presentation/deferred_deletion_snackbar.dart';
import '../../tasks/presentation/task_text.dart';
import '../application/plan_today.dart';
import '../application/plans_providers.dart';
import '../application/topic_actions.dart';
import '../domain/plan.dart';
import '../domain/plan_day_result.dart';
import '../domain/plan_report.dart';
import 'plan_menu.dart';
import 'plan_text.dart';
import 'plan_today_card.dart';
import 'topic_sheet.dart';

/// Situação do dia para a interface; `null` para o dia em andamento.
NexoDayTone? dayToneOf(PlanDayStatus status) => switch (status) {
  PlanDayStatus.met => NexoDayTone.met,
  PlanDayStatus.metShort => NexoDayTone.short,
  PlanDayStatus.metOver => NexoDayTone.over,
  PlanDayStatus.missed => NexoDayTone.missed,
  PlanDayStatus.off => NexoDayTone.off,
  PlanDayStatus.inProgress => null,
};

/// Detalhe do plano (design de Planos 2c, 07/11/2026), dentro da aba
/// Planos: abas Visão geral · Calendário · Sessões (encerrado: Relatório no
/// lugar da Visão geral). O lápis edita; o ⋯ abre o menu do plano.
class PlanDetailPage extends ConsumerStatefulWidget {
  const PlanDetailPage({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends ConsumerState<PlanDetailPage>
    with LeaveOnce<PlanDetailPage>, PlanDayActions<PlanDetailPage> {
  final _moreKey = GlobalKey();
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final plan = ref.watch(planProvider(widget.planId));
    final current = plan.value;
    if (plan.hasValue && current == null) {
      // Excluído (aqui ou em outro lugar): sai.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) leave();
      });
    }
    final primaryId = ref.watch(userProfileProvider).value?.primaryPlanId;
    final today = LocalDate.fromDateTime(ref.watch(screenNowProvider));
    // Regra única de encerrado (Plan.isFinished): igual à lista e ao menu.
    final ended = current != null && current.isFinished(today);
    final open =
        current != null && !ended && current.status != PlanStatus.archived;

    final bar = NexoTopAppBar(
      title: current?.name ?? '',
      onBack: leave,
      actions: [
        if (open)
          NexoIconButton(
            icon: LucideIcons.pencil,
            tooltip: 'Editar plano',
            color: c.iconDefault,
            onPressed: () => context.push(AppRoutes.editPlanOf(current.id)),
          ),
        NexoIconButton(
          key: _moreKey,
          icon: LucideIcons.ellipsis,
          tooltip: 'Mais opções',
          color: c.iconDefault,
          onPressed: current == null
              ? null
              : () {
                  final box =
                      _moreKey.currentContext!.findRenderObject()! as RenderBox;
                  showPlanMenu(
                    context,
                    ref,
                    plan: current,
                    anchor: box.localToGlobal(Offset.zero) & box.size,
                    isPrimary: current.id == primaryId,
                    includeEdit: true,
                    onDeleted: leave,
                  );
                },
        ),
      ],
    );

    final snapshot = ref.watch(planSnapshotProvider(widget.planId));
    if (current == null || snapshot == null) {
      return Scaffold(appBar: bar, body: const SizedBox.expand());
    }

    final tabs = [ended ? 'Relatório' : 'Visão geral', 'Calendário', 'Sessões'];
    return Scaffold(
      appBar: bar,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NexoTabs(
            tabs: [for (final t in tabs) (label: t, count: null)],
            selected: _tab,
            onSelected: (i) => setState(() => _tab = i),
          ),
          Expanded(
            child: switch (_tab) {
              0 => _overview(snapshot, ended: ended),
              1 => _PlanCalendar(snapshot: snapshot),
              _ => _PlanSessions(plan: current),
            },
          ),
        ],
      ),
    );
  }

  // ---------- Visão geral e Relatório ----------

  Widget _overview(PlanSnapshot snapshot, {required bool ended}) {
    final spacing = context.spacing;
    final plan = snapshot.plan;
    final today = LocalDate.fromDateTime(ref.watch(screenNowProvider));
    final report = planReport(snapshot, today: today);
    final planToday = ref.watch(planTodayProvider(plan.id));
    final sessions = ref.watch(planSessionsProvider(plan.id)).value ?? const [];
    final topics = ref.watch(visibleTopicsProvider(plan.id)).value ?? const [];
    final subjects =
        ref.watch(visibleSubjectsProvider).value ?? const <Subject>[];
    final goals = ref.watch(visibleGoalsProvider).value ?? const [];
    final minutesByTopic = topicMinutes(sessions);
    final inPeriod =
        !today.isBefore(plan.startDate) && !today.isAfter(plan.endDate);
    final showToday =
        !ended &&
        plan.status != PlanStatus.archived &&
        planToday != null &&
        (inPeriod || today.isBefore(plan.startDate));

    final sections = <Widget>[
      if (ended)
        _EndedBanner(plan: plan)
      else if (showToday)
        _Block(
          title: 'Hoje',
          child: planTodayCard(planToday, showTitle: false),
        ),
      _Block(
        title: ended ? 'Resultado final' : 'Até ontem',
        child: _StatsGrid(report: report, ended: ended),
      ),
      _Block(
        title: 'Dias do plano',
        child: _DayCounts(report: report),
      ),
      _Block(
        title: 'Tópicos',
        child: NexoCardList(
          children: [
            for (final topic in topics)
              NexoListItem(
                key: ValueKey(topic.id),
                icon: LucideIcons.bookmark,
                title: topic.name,
                supporting:
                    '${topicSupporting(topic.subjectId, subjects)} · '
                    '${formatMinutes(minutesByTopic[topic.id] ?? 0)}',
                showChevron: !ended,
                onTap: ended ? null : () => _editTopic(plan.id, topic),
              ),
            if (!ended)
              NexoAddRow(
                label: 'Adicionar tópico',
                onTap: () => _addTopic(plan.id),
              ),
          ],
        ),
      ),
      if (!ended)
        _Block(
          title: 'Plano',
          child: _ConfigCard(
            rows: [
              (
                'Objetivo',
                goals.where((g) => g.id == plan.goalId).firstOrNull?.name ??
                    'Sem objetivo',
              ),
              ('Período', periodText(plan.startDate, plan.endDate)),
              ('Frequência', frequencyText(plan.frequency)),
              ('Meta diária', formatMinutes(plan.dailyGoalMinutes)),
              ('Horário do plano', studyTimeText(plan)),
            ],
          ),
        ),
      if (ended && plan.status != PlanStatus.archived)
        NexoButton.secondary(
          label: 'Arquivar plano',
          leadingIcon: LucideIcons.archive,
          expand: true,
          onPressed: () async {
            final progress = ref.read(progressActionsProvider);
            final previous = plan.status;
            await progress.archivePlan(plan.id);
            if (!mounted) return;
            showNexoSnackbar(
              context,
              message: 'Plano arquivado.',
              actionLabel: 'Desfazer',
              onAction: () => progress.unarchivePlan(plan.id, previous),
            );
          },
        ),
    ];

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        spacing.lg,
        spacing.lg,
        MediaQuery.paddingOf(context).bottom + spacing.xl,
      ),
      itemCount: sections.length,
      separatorBuilder: (_, _) => SizedBox(height: spacing.xl),
      itemBuilder: (_, i) => sections[i],
    );
  }

  Future<void> _addTopic(String planId) async {
    final result = await showTopicSheet(context);
    if (result == null || result.delete || !mounted) return;
    await ref
        .read(plansRepositoryProvider)
        .addTopic(planId, result.name, subjectId: result.subjectId);
    if (mounted) showNexoSnackbar(context, message: 'Tópico criado.');
  }

  Future<void> _editTopic(String planId, PlanTopic topic) async {
    final result = await showTopicSheet(
      context,
      name: topic.name,
      subjectId: topic.subjectId,
      editing: true,
    );
    if (result == null || !mounted) return;
    final repository = ref.read(plansRepositoryProvider);
    if (result.delete) {
      ref
          .read(topicDeletionProvider)
          .withUndo(
            context,
            topicDeletionKey(planId, topic.id),
            message: 'Tópico excluído.',
          );
      return;
    }
    await repository.updateTopic(
      planId,
      PlanTopic(id: topic.id, name: result.name, subjectId: result.subjectId),
    );
    if (mounted) showNexoSnackbar(context, message: 'Tópico salvo.');
  }
}

/// Uma seção da Visão geral: o `Content/ListHeader` sem recuo (alinhado à
/// borda do cartão) e o conteúdo, cada um no próprio nó do leitor de tela.
class _Block extends StatelessWidget {
  const _Block({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        container: true,
        child: NexoListHeader(title: title, indented: false),
      ),
      Semantics(container: true, explicitChildNodes: true, child: child),
    ],
  );
}

/// Faixa do Relatório: "Plano encerrado em 07/11/2026, antes do fim
/// previsto (10/05/2027)." ou "Plano concluído em …".
class _EndedBanner extends StatelessWidget {
  const _EndedBanner({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final endedOn = plan.endedOn;
    final early = endedOn != null && endedOn.isBefore(plan.endDate);
    final text = early
        ? 'Plano encerrado em ${endedOn.toDisplay()}, antes do fim previsto '
              '(${plan.endDate.toDisplay()}).'
        : 'Plano concluído em ${(endedOn ?? plan.endDate).toDisplay()}.';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.trophy, size: 20, color: c.secondary),
        SizedBox(width: context.spacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium!
                .copyWith(color: c.onSurface),
          ),
        ),
      ],
    );
  }
}

/// "Até ontem" (4 números) ou "Resultado final" (6), em duas colunas.
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.report, required this.ended});

  final PlanReport report;
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final r = report;
    final planned = r.countedDays;
    final percent = planned == 0
        ? 0
        : (r.fulfilledDays * 100 / planned).round();
    final stats = [
      if (ended)
        NexoPlanStat(
          value: '${r.fulfilledDays} de $planned',
          label: 'dias cumpridos',
          detail: '$percent% dos dias planejados',
        ),
      NexoPlanStat(
        value: formatMinutes(r.doneMinutes),
        label: 'dedicadas',
        detail: ended
            ? 'de ${formatMinutes(r.plannedMinutes)} de meta'
            : 'de ${formatMinutes(r.plannedMinutes)} planejadas',
      ),
      NexoPlanStat(
        value: signedMinutes(r.balanceMinutes),
        label: ended ? 'saldo final' : 'saldo',
        detail: 'com a compensação',
      ),
      if (ended)
        NexoPlanStat(
          value: formatMinutes(r.averageMinutes),
          label: 'média por dia',
          detail: 'nos dias com atividade',
        ),
      if (ended)
        NexoPlanStat(
          value: daysCount(r.longestStreak),
          label: 'maior sequência',
          detail: 'de dias cumpridos',
        )
      else
        NexoPlanStat(
          value: daysCount(r.currentStreak),
          label: 'sequência atual',
          detail: 'maior: ${daysCount(r.longestStreak)}',
        ),
      NexoPlanStat(
        value: '${r.points}',
        label: ended ? 'pontos' : 'pontos do plano',
        detail: ended ? 'somados ao seu nível' : 'sobem o seu nível',
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < stats.length; i += 2) ...[
          if (i > 0) SizedBox(height: spacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: stats[i]),
                SizedBox(width: spacing.md),
                Expanded(
                  child: i + 1 < stats.length
                      ? stats[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// "Dias do plano": uma linha por situação, com a contagem.
class _DayCounts extends StatelessWidget {
  const _DayCounts({required this.report});

  final PlanReport report;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final counts = {
      NexoDayTone.met: report.metDays,
      NexoDayTone.short: report.metShortDays,
      NexoDayTone.over: report.metOverDays,
      NexoDayTone.missed: report.missedDays,
      NexoDayTone.off: report.offDays,
    };
    return NexoCardList(
      children: [
        for (final MapEntry(key: tone, value: n) in counts.entries)
          Semantics(
            container: true,
            label: '${tone.label}: ${daysCount(n)}',
            excludeSemantics: true,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.lg,
                vertical: spacing.sm,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Row(
                  children: [
                    Expanded(child: NexoPlanDayStatus(tone: tone)),
                    Text(
                      daysCount(n),
                      style: Theme.of(context).textTheme.labelSmall!
                          .copyWith(color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cartão "Plano": rótulo e valor por linha (BodyMedium).
class _ConfigCard extends StatelessWidget {
  const _ConfigCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    return NexoCardList(
      children: [
        for (final (label, value) in rows)
          // Rótulo e valor lidos juntos ("Objetivo, Sem objetivo").
          Semantics(
            container: true,
            label: '$label, $value',
            excludeSemantics: true,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.lg,
                vertical: spacing.md,
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: spacing.md,
                children: [
                  Text(
                    label,
                    style: textTheme.bodyMedium!.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    style: textTheme.bodyMedium!.copyWith(color: c.onSurface),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------- Calendário ----------

/// Calendário do plano (Planos 18): mês com D S T Q Q S S, as horas sob o
/// número na cor da situação (com texto: "folga", "0", "–"), hoje com anel
/// Primary e o resumo do dia tocado.
class _PlanCalendar extends ConsumerStatefulWidget {
  const _PlanCalendar({required this.snapshot});

  final PlanSnapshot snapshot;

  @override
  ConsumerState<_PlanCalendar> createState() => _PlanCalendarState();
}

class _PlanCalendarState extends ConsumerState<_PlanCalendar> {
  late LocalDate _month;
  late LocalDate _selected;

  @override
  void initState() {
    super.initState();
    final today = LocalDate.fromDateTime(ref.read(screenNowProvider));
    final plan = widget.snapshot.plan;
    final last = plan.endedOn ?? plan.endDate;
    var day = today;
    if (day.isAfter(last)) day = last;
    if (day.isBefore(plan.startDate)) day = plan.startDate;
    _selected = day;
    _month = LocalDate(day.year, day.month, 1);
  }

  void _shift(int months) {
    final m = _month.month + months;
    setState(
      () => _month = LocalDate(
        _month.year + ((m - 1) ~/ 12) - (m < 1 ? 1 : 0),
        ((m - 1) % 12 + 12) % 12 + 1,
        1,
      ),
    );
  }

  String _hours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}min';
    return '${h}h ${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final today = LocalDate.fromDateTime(ref.watch(screenNowProvider));
    final snapshot = widget.snapshot;
    final plan = snapshot.plan;
    final sessions = ref.watch(planSessionsProvider(plan.id)).value ?? const [];
    final topics = {
      // Sem os de exclusão pendente: ficam "sem tópico" na hora.
      for (final t
          in ref.watch(visibleTopicsProvider(plan.id)).value ?? const [])
        t.id: t.name,
    };

    final first = _month;
    final weeks = <List<LocalDate>>[];
    for (
      var week = NexoWeek.startOf(first);
      week.month == first.month || week.isBefore(first);
      week = week.addDays(7)
    ) {
      weeks.add(NexoWeek.daysOf(week));
    }
    final results = <LocalDate, PlanDayResult>{
      for (final w in weeks)
        for (final r in planWeekResults(snapshot, w.first, today: today))
          r.day: r,
    };

    // Dias com horas registradas à mão (até 7 dias atrás): marcados.
    final manualDays = {
      for (final s in sessions)
        if (s.source == SessionSource.manual) s.day,
    };

    Widget cell(LocalDate day) {
      if (day.month != first.month) return const SizedBox.shrink();
      final manual = manualDays.contains(day);
      final r = results[day]!;
      final outside =
          day.isBefore(plan.startDate) ||
          day.isAfter(plan.endedOn ?? plan.endDate);
      final future = day.isAfter(today);
      final tone = dayToneOf(r.status);
      final String below;
      Color belowColor = c.onSurfaceVariant;
      if (outside) {
        below = '';
      } else if (r.status == PlanDayStatus.off) {
        below = r.restDay ? 'folga' : 'pausa';
      } else if (future) {
        below = '–';
      } else if (r.status == PlanDayStatus.missed) {
        below = '0';
        belowColor = tone!.color(c);
      } else if (r.doneMinutes > 0) {
        below = _hours(r.doneMinutes);
        if (tone != null) belowColor = tone.color(c);
      } else {
        below = '–';
      }
      final isToday = day == today;
      final selected = day == _selected;
      final label = [
        dayTitle(day),
        if (below.isNotEmpty) below,
        if (tone != null && !outside && !future) tone.label,
        if (manual) 'com registro manual',
        if (isToday) 'hoje',
      ].join(', ');
      // Ícone da situação junto das horas: a cor não é o único sinal.
      final showIcon =
          !outside && !future && tone != null && tone != NexoDayTone.off;
      return NexoCalendarDay(
        day: day.day,
        below: below,
        belowColor: belowColor,
        icon: showIcon ? tone.icon : null,
        iconColor: showIcon ? tone.color(c) : null,
        today: isToday,
        selected: selected,
        outside: outside,
        manual: manual,
        semanticsLabel: label,
        onTap: () => setState(() => _selected = day),
      );
    }

    final selectedResult = planDayResult(snapshot, _selected, today: today);
    final daySessions = [
      for (final s in sessions)
        if (s.day == _selected) s,
    ];
    final manualCount = daySessions
        .where((s) => s.source == SessionSource.manual)
        .length;
    final topicNames = {
      for (final s in daySessions)
        for (final id in s.topicIds)
          if (topics[id] != null) topics[id]!,
    };
    final tone = dayToneOf(selectedResult.status);
    final statusText = switch (selectedResult.status) {
      PlanDayStatus.met => 'Na meta',
      PlanDayStatus.metOver => 'Com horas a mais',
      PlanDayStatus.metShort => 'Com horas a menos',
      PlanDayStatus.missed => 'Não cumprido',
      PlanDayStatus.off => selectedResult.restDay ? 'Folga' : 'Fora do plano',
      PlanDayStatus.inProgress => 'Em andamento',
    };

    // A grade usa quase toda a largura (margem XS): em 360 dp, cada dia
    // fica com ≥ 48 de largura (alvo de toque). O resto mantém a margem LG.
    final inset = EdgeInsets.symmetric(horizontal: spacing.lg - spacing.xs);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        spacing.xs,
        spacing.md,
        spacing.xs,
        MediaQuery.paddingOf(context).bottom + spacing.xl,
      ),
      children: [
        Padding(
          padding: inset,
          child: Row(
            children: [
              NexoIconButton(
                icon: LucideIcons.chevronLeft,
                tooltip: 'Mês anterior',
                color: c.iconDefault,
                onPressed: () => _shift(-1),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    monthTitle(first.year, first.month),
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium!.copyWith(color: c.onSurface),
                  ),
                ),
              ),
              NexoIconButton(
                icon: LucideIcons.chevronRight,
                tooltip: 'Próximo mês',
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
        for (final week in weeks)
          Row(children: [for (final d in week) Expanded(child: cell(d))]),
        SizedBox(height: spacing.md),
        Padding(
          padding: inset,
          child: Wrap(
            spacing: spacing.md,
            runSpacing: spacing.xs,
            children: [
              for (final t in const [
                (NexoDayTone.met, 'Na meta'),
                (NexoDayTone.over, 'Com horas a mais'),
                (NexoDayTone.short, 'Com horas a menos'),
                (NexoDayTone.missed, 'Não cumprido'),
              ])
                NexoPlanDayStatus(tone: t.$1, text: t.$2),
              // Legenda do lápis (mesmo tamanho de texto das outras).
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(NexoCalendarDay.manualIcon, size: 12, color: c.primary),
                  SizedBox(width: spacing.xs),
                  Flexible(
                    child: Text(
                      'Registro manual',
                      style: textTheme.labelSmall!.copyWith(color: c.onSurface),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.lg),
        Padding(
          padding: inset,
          child: NexoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  dayTitle(_selected),
                  style: context
                      .textStyle(NexoTextStyles.labelMediumEmphasis)
                      .copyWith(color: c.onSurface),
                ),
                SizedBox(height: spacing.sm),
                if (tone != null)
                  NexoPlanDayStatus(
                    tone: tone,
                    text:
                        '$statusText · ${formatMinutes(selectedResult.doneMinutes)}',
                  )
                else
                  Text(
                    '$statusText · ${formatMinutes(selectedResult.doneMinutes)}',
                    style: textTheme.labelSmall!.copyWith(color: c.onSurface),
                  ),
                if (daySessions.isNotEmpty) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    [
                      daySessions.length == 1
                          ? '1 sessão'
                          : '${daySessions.length} sessões',
                      if (manualCount == 1) '1 registro manual',
                      if (manualCount > 1) '$manualCount registros manuais',
                      if (topicNames.isNotEmpty) topicNames.join(', '),
                    ].join(' · '),
                    style: textTheme.labelSmall!.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- Sessões ----------

/// Sessões (Planos 19): "Registrar horas" e as sessões por dia, da mais
/// recente; Foco ou Registro manual; a que cruzou a meia-noite é marcada.
class _PlanSessions extends ConsumerWidget {
  const _PlanSessions({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final today = LocalDate.fromDateTime(ref.watch(screenNowProvider));
    final sessions = [...?ref.watch(planSessionsProvider(plan.id)).value]
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
    final topics = {
      // Sem os de exclusão pendente: ficam "sem tópico" na hora.
      for (final t
          in ref.watch(visibleTopicsProvider(plan.id)).value ?? const [])
        t.id: t.name,
    };
    final byDay = <LocalDate, List<FocusSession>>{};
    for (final s in sessions) {
      (byDay[s.day] ??= []).add(s);
    }

    String dayHeader(LocalDate day) => switch (day.daysUntil(today)) {
      0 => 'Hoje',
      1 => 'Ontem',
      _ => dayTitle(day),
    };

    // Uma sessão dividida à meia-noite vira duas partes: a primeira termina
    // à 00:00 no mesmo instante em que a segunda começa. Só a primeira
    // ganha a marca (uma sessão que só começa ou termina à 00:00, não).
    final starts = {for (final s in sessions) s.startAt};
    bool crossedMidnight(FocusSession s) {
      final end = s.endAt.toLocal();
      final atMidnight = end.hour == 0 && end.minute == 0 && end.second == 0;
      return atMidnight && starts.contains(s.endAt);
    }

    final closed = plan.isFinished(today) || plan.status == PlanStatus.archived;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        spacing.md,
        spacing.lg,
        MediaQuery.paddingOf(context).bottom + spacing.xl,
      ),
      children: [
        if (!closed) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: NexoButton.secondary(
              label: 'Registrar horas',
              leadingIcon: LucideIcons.plus,
              onPressed: () => context.push(AppRoutes.logHoursFor(plan.id)),
            ),
          ),
          SizedBox(height: spacing.md),
        ],
        if (byDay.isEmpty)
          NexoCardList(
            children: [
              NexoEmptyState(
                icon: LucideIcons.timer,
                title: 'Nenhuma sessão ainda',
                message:
                    'As sessões de foco e as horas registradas aparecem aqui, '
                    'por dia.',
              ),
            ],
          ),
        for (final MapEntry(key: day, value: list) in byDay.entries) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      dayHeader(day),
                      style: textTheme.titleMedium!.copyWith(
                        color: c.onSurface,
                      ),
                    ),
                  ),
                ),
                Text(
                  formatMinutes(
                    list.fold(0, (sum, s) => sum + s.durationSeconds) ~/ 60,
                  ),
                  style: textTheme.labelSmall!.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          NexoCardList(
            children: [
              for (final s in list)
                NexoListItem(
                  key: ValueKey(s.id),
                  icon: s.source == SessionSource.manual
                      ? LucideIcons.pencil
                      : LucideIcons.timer,
                  title: [
                    formatMinutes(s.minutes),
                    if (s.topicIds.isEmpty)
                      'sem tópico'
                    else
                      s.topicIds
                          .map((id) => topics[id] ?? 'sem tópico')
                          .join(', '),
                  ].join(' · '),
                  supporting: s.source == SessionSource.manual
                      ? 'Registro manual'
                      : [
                          '${hhmm(s.startAt.toLocal())}–'
                              '${hhmm(s.endAt.toLocal())}',
                          'Foco',
                          if (crossedMidnight(s)) 'cruzou a meia-noite',
                        ].join(' · '),
                  // Só dá para editar até 7 dias atrás (e com o plano aberto).
                  onTap: closed || !isWithinEditWindow(s.day, today: today)
                      ? null
                      : () => context.push(
                          AppRoutes.editSessionOf(plan.id, s.id),
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
