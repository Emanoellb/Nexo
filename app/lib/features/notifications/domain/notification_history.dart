import '../../../core/domain/local_date.dart';
import '../../../core/format/duration_text.dart';
import '../../plans/domain/plan.dart';
import '../../plans/domain/plan_day_result.dart';
import '../../progress/domain/achievements.dart';
import '../../tasks/domain/task.dart';
import 'local_notice.dart';
import 'nexo_notification.dart';

/// Os avisos que o histórico do sino deve ter em [now] (contrato v0.10). O
/// app grava os que ainda não existem, ao abrir e a cada mudança nos dados.
/// O id é fixo por evento, então o mesmo aviso não é gravado duas vezes:
/// - `dueSoon_{tarefa}_{dia do prazo}`: o horário de um dos avisos da tarefa
///   já passou e ela continua pendente, antes do prazo;
/// - `overdue_{tarefa}`: o prazo passou sem concluir, nos últimos 30 dias.
///   Depois disso o TTL apaga o aviso, e o app não grava de novo;
/// - `dailyGoal_{plano}_{dia}`: depois das 21h, a meta de hoje continua
///   aberta (o mesmo critério do aviso das 21h);
/// - `achievement_{medalha}`: medalha ganha nos últimos 30 dias.
///
/// O `createdAt` dos itens é só a referência de agora: quem grava usa o
/// carimbo do servidor.
List<NexoNotification> notificationHistoryAt({
  required DateTime now,
  required List<PlanSnapshot> plans,
  required List<NexoTask> tasks,
  required Map<String, DateTime> earned,
}) {
  final today = LocalDate.fromDateTime(now);
  final since = now.subtract(notificationWindow);
  final items = <NexoNotification>[];

  for (final task in tasks) {
    final due = task.dueAt;
    if (task.completed || due == null) continue;
    if (due.isBefore(now)) {
      if (due.isAfter(since)) {
        items.add(
          NexoNotification(
            id: 'overdue_${task.id}',
            kind: NotificationKind.overdue,
            title: noticeTitle(task.title),
            body: 'A entrega era ${dueText(due, now)}.',
            createdAt: now,
            taskId: task.id,
          ),
        );
      }
      continue;
    }
    final reminded = task.remindersMinutesBefore.any(
      (m) => !due.subtract(Duration(minutes: m)).isAfter(now),
    );
    if (reminded) {
      items.add(
        NexoNotification(
          id: 'dueSoon_${task.id}_${LocalDate.fromDateTime(due).toIso()}',
          kind: NotificationKind.dueSoon,
          title: noticeTitle(task.title),
          body: 'Entrega ${dueText(due, now)}.',
          createdAt: now,
          taskId: task.id,
        ),
      );
    }
  }

  if (now.hour >= dailyGoalNoticeHour) {
    for (final s in plans) {
      if (s.plan.status != PlanStatus.active) continue;
      final result = planDayResult(s, today, today: today);
      if (result.status != PlanDayStatus.inProgress || result.restDay) {
        continue;
      }
      items.add(
        NexoNotification(
          id: 'dailyGoal_${s.plan.id}_${today.toIso()}',
          kind: NotificationKind.dailyGoal,
          title: noticeTitle(s.plan.name),
          body:
              'A meta de hoje ficou em aberto: faltam '
              '${formatMinutes(result.goalMinutes - result.doneMinutes)}.',
          createdAt: now,
          planId: s.plan.id,
          day: today.toIso(),
        ),
      );
    }
  }

  for (final def in NexoAchievements.catalog) {
    final at = earned[def.id];
    if (at == null || !at.isAfter(since)) continue;
    items.add(
      NexoNotification(
        id: 'achievement_${def.id}',
        kind: NotificationKind.achievement,
        title: 'Nova medalha',
        body: def.title,
        createdAt: now,
        achievementId: def.id,
      ),
    );
  }
  return items;
}

/// Limite das regras v0.10 para o título do aviso.
const noticeTitleMaxLength = 120;

/// O título no limite das regras: o título da tarefa vai até 200, e um
/// título maior faria o servidor recusar o aviso.
String noticeTitle(String text) => text.length <= noticeTitleMaxLength
    ? text
    : '${text.substring(0, noticeTitleMaxLength - 1).trimRight()}…';
