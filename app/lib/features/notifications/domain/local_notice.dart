import 'package:flutter/foundation.dart';

import '../../../core/domain/local_date.dart';
import '../../../core/format/duration_text.dart';
import '../../auth/domain/auth_user.dart';
import '../../plans/domain/plan.dart';
import '../../plans/domain/plan_day_result.dart';
import '../../tasks/domain/task.dart';

/// Canal do Android de cada aviso (foco-especificacao.md: Resumo do dia ·
/// Planos · Tarefas · Foco; o do Foco é da notificação fixa).
enum NoticeChannel { daySummary, plans, tasks }

/// Para onde o toque no aviso leva (o `payload` da notificação).
abstract final class NoticeTarget {
  static const home = 'home';
  static String plan(String id) => 'plan:$id';
  static String task(String id) => 'task:$id';
}

/// Um aviso agendado no aparelho (notificação local, sem servidor).
@immutable
class LocalNotice {
  const LocalNotice({
    required this.at,
    required this.channel,
    required this.title,
    required this.body,
    required this.payload,
  });

  final DateTime at;
  final NoticeChannel channel;
  final String title;
  final String body;

  /// [NoticeTarget].
  final String payload;

  @override
  String toString() => 'LocalNotice($at, ${channel.name}, $title, $body)';
}

/// Quantos dias à frente o app agenda. Ao abrir o app e a cada mudança, os
/// avisos são refeitos.
const noticeHorizonDays = 7;

/// Aviso noturno da meta do dia (AGENTS.md, regras de negócio): 21h.
const dailyGoalNoticeHour = 21;

/// Aviso de fim de plano: 7 dias antes do último dia, às 9h.
const planEndNoticeDays = 7;
const planEndNoticeHour = 9;

/// Teto de avisos agendados de uma vez (o Android limita os alarmes por app).
const maxScheduledNotices = 400;

/// Os avisos dos próximos [horizonDays] dias, em ordem de horário:
/// - **Resumo do dia** (aviso da manhã, `users.morningSummary`): os planos
///   com estudo e as entregas do dia; sem nada no dia, não avisa;
/// - **antes do horário do plano** (`reminderBefore`, ligado), nos dias de
///   estudo com a meta ainda aberta;
/// - **meta do dia às 21h**, nos dias de estudo com a meta ainda aberta.
///   Na leitura aprovada em 12/11/2026, vale mesmo quando o aviso de antes
///   saiu no mesmo dia;
/// - **7 dias do fim** do plano;
/// - **entrega da tarefa**: cada item de `remindersMinutesBefore` antes do
///   prazo, com a tarefa pendente.
///
/// Só planos ativos. Quando a meta é batida ou a tarefa concluída, o app
/// refaz a lista e o aviso sai.
List<LocalNotice> planLocalNotices({
  required DateTime now,
  required MorningSummary morningSummary,
  required List<PlanSnapshot> plans,
  required List<NexoTask> tasks,
  int horizonDays = noticeHorizonDays,
}) {
  final today = LocalDate.fromDateTime(now);
  final end = today.addDays(horizonDays).startOfDay;
  final notices = <LocalNotice>[];

  void add(LocalNotice notice) {
    if (notice.at.isAfter(now) && notice.at.isBefore(end)) {
      notices.add(notice);
    }
  }

  final active = [
    for (final s in plans)
      if (s.plan.status == PlanStatus.active) s,
  ];

  for (var i = 0; i < horizonDays; i++) {
    final day = today.addDays(i);

    // Planos com estudo e meta aberta no dia.
    final studying = <(PlanSnapshot, PlanDayResult)>[];
    for (final s in active) {
      final result = planDayResult(s, day, today: today);
      if (result.status == PlanDayStatus.inProgress && !result.restDay) {
        studying.add((s, result));
      }
    }

    for (final (s, result) in studying) {
      final plan = s.plan;
      final left = formatMinutes(result.goalMinutes - result.doneMinutes);
      final reminder = plan.reminderBefore;
      if (reminder.enabled) {
        add(
          LocalNotice(
            at: _at(
              day,
              plan.studyTime,
            ).subtract(Duration(minutes: reminder.minutesBefore)),
            channel: NoticeChannel.plans,
            title: plan.name,
            body: reminder.minutesBefore == 0
                ? 'Está na hora. Faltam $left para a meta do dia.'
                : 'Começa em ${formatMinutes(reminder.minutesBefore)}. '
                      'Faltam $left para a meta do dia.',
            payload: NoticeTarget.plan(plan.id),
          ),
        );
      }
      add(
        LocalNotice(
          at: day.startOfDay.add(const Duration(hours: dailyGoalNoticeHour)),
          channel: NoticeChannel.plans,
          title: plan.name,
          body: 'Faltam $left para a meta de hoje.',
          payload: NoticeTarget.home,
        ),
      );
    }

    for (final s in active) {
      final plan = s.plan;
      if (plan.endedOn != null) continue;
      if (plan.endDate.addDays(-planEndNoticeDays) != day) continue;
      add(
        LocalNotice(
          at: day.startOfDay.add(const Duration(hours: planEndNoticeHour)),
          channel: NoticeChannel.plans,
          title: plan.name,
          body: 'Faltam $planEndNoticeDays dias para o fim do plano.',
          payload: NoticeTarget.plan(plan.id),
        ),
      );
    }

    if (morningSummary.enabled) {
      final due = [
        for (final t in tasks)
          if (!t.completed &&
              t.dueAt != null &&
              LocalDate.fromDateTime(t.dueAt!) == day)
            t,
      ];
      final body = _summaryBody(studying, due.length);
      if (body != null) {
        add(
          LocalNotice(
            at: _at(day, morningSummary.time),
            channel: NoticeChannel.daySummary,
            title: 'Seu dia',
            body: body,
            payload: NoticeTarget.home,
          ),
        );
      }
    }
  }

  for (final task in tasks) {
    final due = task.dueAt;
    if (task.completed || due == null) continue;
    for (final minutes in task.remindersMinutesBefore) {
      final at = due.subtract(Duration(minutes: minutes));
      add(
        LocalNotice(
          at: at,
          channel: NoticeChannel.tasks,
          title: task.title,
          body: 'Entrega ${dueText(due, at)}.',
          payload: NoticeTarget.task(task.id),
        ),
      );
    }
  }

  notices.sort((a, b) => a.at.compareTo(b.at));
  return notices.length > maxScheduledNotices
      ? notices.sublist(0, maxScheduledNotices)
      : notices;
}

/// "Concurso: meta de 1h 30min · 2 entregas". `null` sem nada no dia.
String? _summaryBody(List<(PlanSnapshot, PlanDayResult)> studying, int due) {
  final parts = <String>[
    if (studying.length == 1)
      '${studying.single.$1.plan.name}: meta de '
          '${formatMinutes(studying.single.$2.goalMinutes)}'
    else if (studying.length > 1)
      '${studying.length} planos para estudar',
    if (due == 1) '1 entrega' else if (due > 1) '$due entregas',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// [day] no horário "HH:mm".
DateTime _at(LocalDate day, String time) {
  final parts = time.split(':');
  return DateTime(
    day.year,
    day.month,
    day.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}

/// O prazo visto da hora do aviso: "hoje às 18:00", "amanhã às 18:00" ou
/// "em 14/11 às 18:00".
String dueText(DateTime due, DateTime at) {
  final dueDay = LocalDate.fromDateTime(due);
  final diff = LocalDate.fromDateTime(at).daysUntil(dueDay);
  final time =
      '${due.hour.toString().padLeft(2, '0')}:'
      '${due.minute.toString().padLeft(2, '0')}';
  final day = switch (diff) {
    0 => 'hoje',
    1 => 'amanhã',
    _ =>
      'em ${dueDay.day.toString().padLeft(2, '0')}/'
          '${dueDay.month.toString().padLeft(2, '0')}',
  };
  return '$day às $time';
}
