import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/data/clock.dart';
import '../../../core/domain/edit_window.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/format/duration_text.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../plans/application/plans_providers.dart';
import '../../plans/domain/plan.dart';
import '../../progress/application/progress_actions.dart';
import '../../tasks/presentation/task_text.dart';
import '../domain/focus_session.dart';
import '../domain/session_split.dart';
import 'session_topics.dart';

/// "Hoje, sex 7/11", "Ontem, qui 6/11" ou "Qua, 5/11".
String sessionDayText(LocalDate day, LocalDate today) {
  final short = '${weekdayShortLower(day)} ${day.day}/${day.month}';
  return switch (day.daysUntil(today)) {
    0 => 'Hoje, $short',
    1 => 'Ontem, $short',
    _ => '${short[0].toUpperCase()}${short.substring(1)}',
  };
}

/// Registrar horas (tela 10, tela cheia com X) e Editar sessão (tela 12, com
/// voltar): plano (só ao registrar), dia (até 7 dias atrás), início e fim,
/// a duração calculada, tópicos (até 3) e nota. Editar tem "Excluir sessão"
/// com Desfazer. As horas entram no dia e ajustam os pontos da semana.
class SessionFormPage extends ConsumerStatefulWidget {
  const SessionFormPage.create({super.key, this.planId}) : sessionId = null;

  const SessionFormPage.edit({
    super.key,
    required String this.planId,
    required String this.sessionId,
  });

  final String? planId;

  /// `null` = Registrar horas.
  final String? sessionId;

  @override
  ConsumerState<SessionFormPage> createState() => _SessionFormPageState();
}

class _SessionFormPageState extends ConsumerState<SessionFormPage>
    with LeaveOnce<SessionFormPage> {
  final _note = TextEditingController();
  late String? _planId = widget.planId;
  LocalDate? _day;
  TimeOfDay? _start;
  TimeOfDay? _end;
  List<String> _topics = const [];
  FocusSession? _original;
  bool _showErrors = false;
  bool _saving = false;

  bool get _editing => widget.sessionId != null;

  LocalDate get _today => LocalDate.fromDateTime(ref.read(clockProvider)());

  @override
  void initState() {
    super.initState();
    _day = _today;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _load(FocusSession session) {
    if (_original != null) return;
    _original = session;
    _day = session.day;
    _start = TimeOfDay.fromDateTime(session.startAt.toLocal());
    _end = TimeOfDay.fromDateTime(session.endAt.toLocal());
    _topics = session.topicIds;
    _note.text = session.note ?? '';
  }

  DateTime? _at(TimeOfDay? t) {
    final day = _day;
    if (day == null || t == null) return null;
    return DateTime(day.year, day.month, day.day, t.hour, t.minute);
  }

  /// Editar sem mexer no dia nem no horário: o formulário mostra só hora e
  /// minuto, então a comparação é por eles. Vale também para a primeira
  /// parte de uma sessão dividida à meia-noite (termina às 00:00 do dia
  /// seguinte).
  bool get _sameTimes {
    final original = _original;
    return original != null &&
        _day == original.day &&
        _start == TimeOfDay.fromDateTime(original.startAt.toLocal()) &&
        _end == TimeOfDay.fromDateTime(original.endAt.toLocal());
  }

  /// Erros por campo (ou `null`).
  ({String? day, String? end}) _errors() {
    final day = _day;
    String? dayError;
    if (day == null || !isWithinEditWindow(day, today: _today)) {
      dayError = 'Só dá para registrar até 7 dias atrás.';
    }
    final start = _at(_start);
    final end = _at(_end);
    String? endError;
    if (_sameTimes) {
      endError = null;
    } else if (start == null || end == null) {
      endError = 'Escolha o início e o fim.';
    } else if (!end.isAfter(start)) {
      endError = 'O fim precisa ser depois do início.';
    } else if (end.isAfter(
      ref.read(clockProvider)().add(const Duration(minutes: 5)),
    )) {
      endError = 'O fim não pode ser depois de agora.';
    }
    return (day: dayError, end: endError);
  }

  Future<void> _pickPlan(Rect anchor, List<Plan> plans) async {
    final chosen = await showNexoMenu(
      context,
      anchor: anchor,
      label: 'Plano',
      alignEnd: false,
      items: [
        for (final p in plans)
          NexoMenuItem(label: p.name, selected: p.id == _planId),
      ],
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _planId = plans[chosen].id;
      _topics = const [];
    });
  }

  Future<void> _pickDay(Rect anchor) async {
    final today = _today;
    final days = [for (var i = 0; i <= editWindowDays; i++) today.addDays(-i)];
    final chosen = await showNexoMenu(
      context,
      anchor: anchor,
      label: 'Dia',
      alignEnd: false,
      items: [
        for (final d in days)
          NexoMenuItem(label: sessionDayText(d, today), selected: d == _day),
      ],
    );
    if (chosen != null && mounted) setState(() => _day = days[chosen]);
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.fromDateTime(ref.read(clockProvider)()),
      helpText: start ? 'Início' : 'Fim',
    );
    if (picked == null || !mounted) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  Future<void> _save() async {
    final errors = _errors();
    final planId = _planId;
    if (errors.day != null || errors.end != null || planId == null) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    final progress = ref.read(progressActionsProvider);
    final start = _at(_start)!;
    final end = _at(_end)!;
    final note = _note.text.trim();
    final original = _original;
    if (original == null) {
      await progress.addSessions(
        planId,
        [
          DaySegment(
            day: _day!,
            startAt: start,
            endAt: end,
            durationSeconds: end.difference(start).inSeconds,
          ),
        ],
        source: SessionSource.manual,
        topicIds: _topics,
        note: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      showNexoSnackbar(context, message: 'Horas registradas.');
    } else {
      // Sem mudar o dia nem o horário, os horários exatos e a duração
      // líquida (sem as pausas) continuam.
      final sameTimes = _sameTimes;
      await progress.updateSession(
        planId,
        original,
        FocusSession(
          id: original.id,
          planId: planId,
          startAt: sameTimes ? original.startAt : start,
          endAt: sameTimes ? original.endAt : end,
          durationSeconds: sameTimes
              ? original.durationSeconds
              : end.difference(start).inSeconds,
          source: original.source,
          day: _day!,
          topicIds: _topics,
          note: note.isEmpty ? null : note,
        ),
      );
      if (!mounted) return;
      showNexoSnackbar(context, message: 'Alterações salvas.');
    }
    leave();
  }

  Future<void> _delete(FocusSession session) async {
    final progress = ref.read(progressActionsProvider);
    await progress.deleteSessions(session.planId, [session]);
    if (!mounted) return;
    showNexoSnackbar(
      context,
      message: 'Sessão excluída.',
      actionLabel: 'Desfazer',
      onAction: () => progress.addSessions(
        session.planId,
        [
          DaySegment(
            day: session.day,
            startAt: session.startAt,
            endAt: session.endAt,
            durationSeconds: session.durationSeconds,
          ),
        ],
        source: session.source,
        topicIds: session.topicIds,
        note: session.note,
      ),
    );
    leave();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final today = LocalDate.fromDateTime(ref.watch(clockProvider)());

    FocusSession? session;
    if (_editing) {
      final sessions = ref.watch(planSessionsProvider(widget.planId!));
      session = sessions.value
          ?.where((s) => s.id == widget.sessionId)
          .firstOrNull;
      if (session != null) {
        _load(session);
      } else if (sessions.hasValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) leave();
        });
      }
    }
    final plans = [
      for (final p in ref.watch(plansProvider).value ?? const <Plan>[])
        if (p.status == PlanStatus.active || p.status == PlanStatus.paused) p,
    ];
    _planId ??= plans.firstOrNull?.id;
    final plan = plans.where((p) => p.id == _planId).firstOrNull;

    final bar = NexoTopAppBar(
      title: _editing ? 'Editar sessão' : 'Registrar horas',
      closeIcon: !_editing,
      onBack: leave,
    );
    if (_editing && session == null) {
      return Scaffold(appBar: bar, body: const SizedBox.expand());
    }

    final errors = _showErrors ? _errors() : (day: null, end: null);
    final start = _at(_start);
    final end = _at(_end);
    // Sem mexer no horário, a duração é a líquida da sessão (sem pausas).
    final duration = _sameTimes
        ? formatMinutes(_original!.minutes)
        : start != null && end != null && end.isAfter(start)
        ? formatMinutes(end.difference(start).inMinutes)
        : '—';
    final origin = session == null
        ? null
        : '${session.source == SessionSource.focus ? 'Sessão de foco' : 'Registro manual'} · ${relativeDayText(session.day, today)}';

    return Scaffold(
      appBar: bar,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                spacing.lg,
                spacing.sm,
                spacing.lg,
                spacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (origin != null) ...[
                    Text(
                      origin,
                      style: textTheme.bodyMedium!.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: spacing.lg),
                  ],
                  if (!_editing) ...[
                    NexoSelectField(
                      label: 'Plano',
                      leadingIcon: LucideIcons.target,
                      value: plan?.name,
                      placeholder: 'Escolha um plano',
                      onTap: plans.isEmpty
                          ? null
                          : (anchor) => _pickPlan(anchor, plans),
                    ),
                    SizedBox(height: spacing.lg),
                  ],
                  NexoSelectField(
                    label: 'Dia',
                    leadingIcon: LucideIcons.calendar,
                    value: _day == null ? null : sessionDayText(_day!, today),
                    placeholder: 'Escolha o dia',
                    helperText: 'Até 7 dias atrás.',
                    errorText: errors.day,
                    onTap: _pickDay,
                  ),
                  SizedBox(height: spacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: NexoSelectField(
                          label: 'Início',
                          trailingIcon: LucideIcons.clock3,
                          value: start == null ? null : hhmm(start),
                          placeholder: '—',
                          onTap: (_) => _pickTime(start: true),
                        ),
                      ),
                      SizedBox(width: spacing.md),
                      Expanded(
                        child: NexoSelectField(
                          label: 'Fim',
                          trailingIcon: LucideIcons.clock3,
                          value: end == null ? null : hhmm(end),
                          placeholder: '—',
                          errorText: errors.end,
                          onTap: (_) => _pickTime(start: false),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.lg),
                  Semantics(
                    container: true,
                    label: 'Duração, $duration',
                    excludeSemantics: true,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Duração',
                            style: textTheme.labelMedium!.copyWith(
                              color: c.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          duration,
                          style: context
                              .textStyle(NexoTextStyles.labelMediumEmphasis)
                              .copyWith(color: c.onSurface),
                        ),
                      ],
                    ),
                  ),
                  if (_planId != null) ...[
                    SizedBox(height: spacing.lg),
                    Semantics(
                      header: true,
                      child: Text(
                        'Tópicos',
                        style: textTheme.labelMedium!.copyWith(
                          color: c.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.sm),
                    SessionTopicsField(
                      planId: _planId!,
                      topicIds: _topics,
                      helper:
                          'Opcional · até 3. As horas são divididas '
                          'igualmente entre eles.',
                      onChanged: (ids) => setState(() => _topics = ids),
                    ),
                  ],
                  SizedBox(height: spacing.lg),
                  NexoTextField(
                    label: 'Nota',
                    hintText: 'Ex.: Resolvi a lista 3 de juros.',
                    helperText: 'Opcional · até 500 caracteres.',
                    controller: _note,
                    minLines: 2,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [LengthLimitingTextInputFormatter(500)],
                  ),
                  if (session != null) ...[
                    SizedBox(height: spacing.lg),
                    NexoButton.destructiveLow(
                      label: 'Excluir sessão',
                      leadingIcon: LucideIcons.trash2,
                      expand: true,
                      onPressed: isWithinEditWindow(session.day, today: today)
                          ? () => _delete(session!)
                          : null,
                    ),
                  ],
                ],
              ),
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
              child: NexoButton.primary(
                label: 'Salvar',
                leadingIcon: LucideIcons.check,
                expand: true,
                loading: _saving,
                onPressed: plan == null && !_editing ? null : _save,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
