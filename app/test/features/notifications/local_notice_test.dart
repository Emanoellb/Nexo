import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/auth/domain/auth_user.dart';
import 'package:nexo/features/notifications/domain/local_notice.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/plans/domain/plan_day_result.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';
import 'package:nexo/features/tasks/domain/task.dart';

// Quarta, 11/11/2026, 10:00.
final _now = DateTime(2026, 11, 11, 10);
const _today = LocalDate(2026, 11, 11);
const _off = MorningSummary(enabled: false, time: '08:00');

PlanSnapshot _plan({
  String id = 'p1',
  PlanFrequency frequency = const DailyFrequency(),
  PlanStatus status = PlanStatus.active,
  LocalDate? endDate,
  bool reminder = true,
  int minutesBefore = 15,
  Map<LocalDate, int> done = const {},
}) {
  final plan = Plan(
    id: id,
    name: 'Concurso',
    startDate: _today.addDays(-3),
    endDate: endDate ?? _today.addDays(60),
    frequency: frequency,
    dailyGoalMinutes: 90,
    status: status,
    reminderBefore: PlanReminderBefore(
      enabled: reminder,
      minutesBefore: minutesBefore,
    ),
  );
  return PlanSnapshot(
    plan: plan,
    versions: [
      ScheduleVersion(
        effectiveFrom: plan.startDate,
        frequency: frequency,
        dailyGoalMinutes: 90,
      ),
    ],
    days: [
      for (final MapEntry(key: day, value: minutes) in done.entries)
        PlanDay(day: day, doneMinutes: minutes),
    ],
  );
}

List<LocalNotice> _plan7({
  List<PlanSnapshot> plans = const [],
  List<NexoTask> tasks = const [],
  MorningSummary morning = _off,
  DateTime? now,
}) => planLocalNotices(
  now: now ?? _now,
  morningSummary: morning,
  plans: plans,
  tasks: tasks,
);

DateTime _on(int dayOffset, int hour, [int minute = 0]) {
  final d = _today.addDays(dayOffset);
  return DateTime(d.year, d.month, d.day, hour, minute);
}

void main() {
  group('plano', () {
    test('antes do horário e meta às 21h, nos 7 dias', () {
      final notices = _plan7(plans: [_plan()]);
      expect(notices, hasLength(14));
      final today = notices.where((n) => n.at.day == _today.day).toList();
      expect([for (final n in today) n.at], [_on(0, 18, 45), _on(0, 21)]);
      expect(today.first.channel, NoticeChannel.plans);
      expect(today.first.title, 'Concurso');
      expect(
        today.first.body,
        'Começa em 15 min. Faltam 1h 30min para a meta do dia.',
      );
      expect(today.first.payload, NoticeTarget.plan('p1'));
      expect(today.last.body, 'Faltam 1h 30min para a meta de hoje.');
      expect(today.last.payload, NoticeTarget.home);
      // Em ordem de horário, até o 7º dia.
      expect(notices.last.at, _on(6, 21));
    });

    test('o que falta conta o estudo de hoje', () {
      final notices = _plan7(
        plans: [
          _plan(done: {_today: 60}),
        ],
      );
      expect(notices.first.body, contains('Faltam 30 min'));
    });

    test('meta batida hoje: sem aviso hoje', () {
      final notices = _plan7(
        plans: [
          _plan(done: {_today: 90}),
        ],
      );
      expect(notices.where((n) => n.at.day == _today.day), isEmpty);
      expect(notices, hasLength(12));
    });

    test('"Na hora" e aviso de antes desligado', () {
      final atTime = _plan7(plans: [_plan(minutesBefore: 0)]);
      expect(atTime.first.at, _on(0, 19));
      expect(atTime.first.body, startsWith('Está na hora.'));

      final noReminder = _plan7(plans: [_plan(reminder: false)]);
      expect(noReminder, hasLength(7));
      expect(noReminder.every((n) => n.at.hour == 21), isTrue);
    });

    test('só nos dias da semana escolhidos', () {
      // Segunda, quarta e sexta: qua 11, sex 13, seg 16.
      final notices = _plan7(
        plans: [
          _plan(frequency: WeekdaysFrequency({1, 3, 5})),
        ],
      );
      expect({for (final n in notices) n.at.day}, {11, 13, 16});
    });

    test('pausado ou arquivado: nada', () {
      expect(_plan7(plans: [_plan(status: PlanStatus.paused)]), isEmpty);
      expect(_plan7(plans: [_plan(status: PlanStatus.archived)]), isEmpty);
    });

    test('horário que já passou hoje fica de fora', () {
      final notices = _plan7(plans: [_plan()], now: _on(0, 22));
      expect(notices.where((n) => n.at.day == _today.day), isEmpty);
    });

    test('7 dias antes do fim, às 9h', () {
      final notices = _plan7(
        plans: [_plan(endDate: _today.addDays(10), reminder: false)],
      );
      final end = notices.where((n) => n.body.contains('fim do plano'));
      expect(end.single.at, _on(3, 9));
      expect(end.single.payload, NoticeTarget.plan('p1'));
    });
  });

  group('aviso da manhã', () {
    const morning = MorningSummary(enabled: true, time: '08:00');

    NexoTask task(String id, DateTime due, {bool completed = false}) =>
        NexoTask(id: id, title: 'Tarefa $id', dueAt: due, completed: completed);

    test('planos e entregas do dia; sem nada, sem aviso', () {
      final notices = _plan7(
        plans: [_plan(reminder: false)],
        tasks: [
          task('a', _on(1, 18)),
          task('b', _on(1, 23, 59)),
          task('c', _on(1, 12), completed: true),
        ],
        morning: morning,
      ).where((n) => n.channel == NoticeChannel.daySummary).toList();
      // Hoje às 8h já passou: amanhã em diante.
      expect(notices.first.at, _on(1, 8));
      expect(notices.first.title, 'Seu dia');
      expect(notices.first.body, 'Concurso: meta de 1h 30min · 2 entregas');
      expect(notices[1].body, 'Concurso: meta de 1h 30min');
      expect(notices.first.payload, NoticeTarget.home);

      final empty = _plan7(morning: morning);
      expect(empty, isEmpty);
    });

    test('desligado: nada', () {
      expect(
        _plan7(plans: [_plan(reminder: false)])
            .where((n) => n.channel == NoticeChannel.daySummary),
        isEmpty,
      );
    });
  });

  group('tarefa', () {
    test('cada aviso antes do prazo, só pendente e dentro de 7 dias', () {
      final notices = _plan7(
        tasks: [
          NexoTask(
            id: 't1',
            title: 'Lista 3',
            dueAt: _on(1, 18),
            remindersMinutesBefore: const [1440, 60],
          ),
          NexoTask(
            id: 't2',
            title: 'Feita',
            dueAt: _on(1, 18),
            completed: true,
            remindersMinutesBefore: const [60],
          ),
          NexoTask(
            id: 't3',
            title: 'Longe',
            dueAt: _on(20, 18),
            remindersMinutesBefore: const [60],
          ),
        ],
      );
      expect([for (final n in notices) n.at], [_on(0, 18), _on(1, 17)]);
      expect(notices.first.body, 'Entrega amanhã às 18:00.');
      expect(notices.last.body, 'Entrega hoje às 18:00.');
      expect(notices.first.channel, NoticeChannel.tasks);
      expect(notices.first.payload, NoticeTarget.task('t1'));
    });

    test('prazo depois de amanhã: com a data', () {
      final notices = _plan7(
        tasks: [
          NexoTask(
            id: 't1',
            title: 'Trabalho',
            dueAt: _on(4, 23, 59),
            remindersMinutesBefore: const [4320],
          ),
        ],
      );
      expect(notices.single.body, 'Entrega em 15/11 às 23:59.');
    });
  });
}
