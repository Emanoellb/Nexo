import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/notifications/domain/nexo_notification.dart';
import 'package:nexo/features/notifications/domain/notification_history.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/plans/domain/plan_day_result.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';
import 'package:nexo/features/tasks/domain/task.dart';

const _today = LocalDate(2026, 11, 11);
DateTime _at(int hour, [int minute = 0, int dayOffset = 0]) {
  final d = _today.addDays(dayOffset);
  return DateTime(d.year, d.month, d.day, hour, minute);
}

PlanSnapshot _plan({int doneToday = 0}) {
  final plan = Plan(
    id: 'p1',
    name: 'Concurso',
    startDate: _today.addDays(-3),
    endDate: _today.addDays(60),
    frequency: const DailyFrequency(),
    dailyGoalMinutes: 90,
  );
  return PlanSnapshot(
    plan: plan,
    versions: [
      ScheduleVersion(
        effectiveFrom: plan.startDate,
        frequency: plan.frequency,
        dailyGoalMinutes: 90,
      ),
    ],
    days: [PlanDay(day: _today, doneMinutes: doneToday)],
  );
}

List<NexoNotification> _history({
  DateTime? now,
  List<PlanSnapshot> plans = const [],
  List<NexoTask> tasks = const [],
  Map<String, DateTime> earned = const {},
}) => notificationHistoryAt(
  now: now ?? _at(10),
  plans: plans,
  tasks: tasks,
  earned: earned,
);

void main() {
  group('tarefa', () {
    test('atrasada: overdue com a tarefa ligada', () {
      final items = _history(
        tasks: [NexoTask(id: 't1', title: 'Lista 3', dueAt: _at(9))],
      );
      expect(items.single.id, 'overdue_t1');
      expect(items.single.kind, NotificationKind.overdue);
      expect(items.single.taskId, 't1');
      expect(items.single.body, 'A entrega era hoje às 09:00.');
    });

    test('atrasada há mais de 30 dias: não grava (o TTL já apagou)', () {
      final items = _history(
        tasks: [NexoTask(id: 't1', title: 'Antiga', dueAt: _at(9, 0, -31))],
      );
      expect(items, isEmpty);
    });

    test('entrega próxima depois do horário do aviso', () {
      final task = NexoTask(
        id: 't1',
        title: 'Lista 3',
        dueAt: _at(18, 0, 1),
        remindersMinutesBefore: const [1440, 60],
      );
      // Antes do aviso de 1 dia: nada.
      expect(_history(tasks: [task]), isEmpty);
      final items = _history(now: _at(18, 30), tasks: [task]);
      expect(items.single.id, 'dueSoon_t1_2026-11-12');
      expect(items.single.body, 'Entrega amanhã às 18:00.');
    });

    test('concluída ou sem prazo: nada', () {
      expect(
        _history(
          tasks: [
            NexoTask(id: 'a', title: 'Feita', dueAt: _at(9), completed: true),
            NexoTask(id: 'b', title: 'Sem prazo'),
          ],
        ),
        isEmpty,
      );
    });
  });

  group('meta do dia', () {
    test('depois das 21h com a meta aberta', () {
      expect(_history(now: _at(20), plans: [_plan()]), isEmpty);
      final items = _history(now: _at(21, 5), plans: [_plan(doneToday: 60)]);
      expect(items.single.id, 'dailyGoal_p1_2026-11-11');
      expect(items.single.planId, 'p1');
      expect(items.single.day, '2026-11-11');
      expect(
        items.single.body,
        'A meta de hoje ficou em aberto: faltam 30 min.',
      );
    });

    test('meta batida: nada', () {
      expect(_history(now: _at(22), plans: [_plan(doneToday: 90)]), isEmpty);
    });
  });

  test('medalha dos últimos 30 dias', () {
    final items = _history(
      earned: {'primeiro-plano': _at(9), 'primeiro-foco': _at(9, 0, -40)},
    );
    expect(items.single.id, 'achievement_primeiro-plano');
    expect(items.single.title, 'Nova medalha');
    expect(items.single.achievementId, 'primeiro-plano');
  });

  test('título acima de 120 é cortado (limite das regras)', () {
    final items = _history(
      tasks: [NexoTask(id: 't1', title: 'x' * 200, dueAt: _at(9))],
    );
    expect(items.single.title.length, noticeTitleMaxLength);
    expect(items.single.title, endsWith('…'));
  });
}
