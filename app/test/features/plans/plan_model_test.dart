import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/focus/domain/focus_session.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';

Plan _plan({
  String name = 'Concurso Banco Horizonte',
  LocalDate start = const LocalDate(2026, 10, 1),
  LocalDate end = const LocalDate(2027, 3, 1),
  int goal = 90,
  PlanStatus status = PlanStatus.active,
  LocalDate? endedOn,
  List<PlanPause> pauses = const [],
}) => Plan(
  id: 'p1',
  name: name,
  startDate: start,
  endDate: end,
  frequency: WeekdaysFrequency({1, 3, 5}),
  dailyGoalMinutes: goal,
  status: status,
  endedOn: endedOn,
  pauses: pauses,
  studyTime: '19:30',
);

void main() {
  group('Plan: limites das regras', () {
    test('nome de 1 a 80 caracteres', () {
      expect(() => _plan(name: ''), throwsArgumentError);
      expect(() => _plan(name: 'x' * 81), throwsArgumentError);
      expect(_plan(name: 'x' * 80).name.length, 80);
    });

    test('meta diária de 1 a 1440 minutos', () {
      expect(() => _plan(goal: 0), throwsArgumentError);
      expect(() => _plan(goal: 1441), throwsArgumentError);
    });

    test('fim depois do início e período de até 731 dias', () {
      const start = LocalDate(2026, 10, 1);
      expect(
        () => _plan(start: start, end: start.addDays(-1)),
        throwsArgumentError,
      );
      expect(
        _plan(start: start, end: start.addDays(731)).endDate,
        start.addDays(731),
      );
      expect(
        () => _plan(start: start, end: start.addDays(732)),
        throwsArgumentError,
      );
    });

    test('encerrado antes exige endedOn dentro do período', () {
      expect(() => _plan(status: PlanStatus.endedEarly), throwsArgumentError);
      expect(
        () => _plan(
          status: PlanStatus.endedEarly,
          endedOn: const LocalDate(2027, 4, 1),
        ),
        throwsArgumentError,
      );
    });

    test('até 100 pausas', () {
      final pause = PlanPause(start: const LocalDate(2026, 10, 2));
      expect(() => _plan(pauses: List.filled(101, pause)), throwsArgumentError);
    });

    test('horário do plano em HH:mm; antecedência 0, 15, 30 ou 60', () {
      expect(() => _plan().copyWith(studyTime: '7:00'), throwsArgumentError);
      expect(() => _plan().copyWith(studyTime: '24:00'), throwsArgumentError);
      expect(
        () => PlanReminderBefore(enabled: true, minutesBefore: 45),
        throwsArgumentError,
      );
      for (final m in PlanReminderBefore.options) {
        expect(
          PlanReminderBefore(enabled: true, minutesBefore: m).minutesBefore,
          m,
        );
      }
    });

    test('padrões da v0.9: 19:00 e aviso ligado 15 min antes', () {
      final plan = Plan(
        id: 'p',
        name: 'Treino',
        startDate: const LocalDate(2026, 11, 1),
        endDate: const LocalDate(2026, 12, 1),
        frequency: const DailyFrequency(),
        dailyGoalMinutes: 60,
      );
      expect(plan.studyTime, '19:00');
      expect(plan.reminderBefore, PlanReminderBefore.standard);
      final map = plan.toMap();
      expect(map['studyTime'], '19:00');
      expect(map['reminderBefore'], {'enabled': true, 'minutesBefore': 15});
      expect(map.containsKey('reminder'), isFalse);
      final back = Plan.fromMap('p', {...map}..remove('studyTime'));
      expect(back.studyTime, '19:00');
    });
  });

  test('Plan: ida e volta pelo mapa do Firestore', () {
    final plan = _plan(
      status: PlanStatus.endedEarly,
      endedOn: const LocalDate(2026, 12, 1),
      pauses: [
        const PlanPause(
          start: LocalDate(2026, 10, 10),
          end: LocalDate(2026, 10, 12),
        ),
      ],
    );
    final map = plan.toMap();
    expect(map['startDate'], '2026-10-01');
    expect(map['dailyGoalMinutes'], isA<int>());
    expect(map['frequency'], {
      'type': 'weekdays',
      'weekdays': [1, 3, 5],
    });

    final back = Plan.fromMap('p1', map);
    expect(back.toMap(), map);
  });

  group('FocusSession: limites das regras', () {
    final start = DateTime(2026, 10, 26, 9);

    FocusSession session({
      Duration length = const Duration(hours: 1),
      int? seconds,
    }) => FocusSession(
      id: 's1',
      planId: 'p1',
      startAt: start,
      endAt: start.add(length),
      durationSeconds: seconds ?? length.inSeconds,
      source: SessionSource.focus,
      day: const LocalDate(2026, 10, 26),
    );

    test('duração líquida maior que zero e que cabe entre início e fim', () {
      expect(session(seconds: 1800).minutes, 30);
      expect(() => session(seconds: 0), throwsArgumentError);
      expect(() => session(seconds: 3601), throwsArgumentError);
    });

    test('até 24 horas', () {
      expect(
        () => session(length: const Duration(hours: 25)),
        throwsArgumentError,
      );
    });

    test('mapa com o dia em AAAA-MM-DD e a origem', () {
      final map = session().toMap();
      expect(map['day'], '2026-10-26');
      expect(map['source'], 'focus');
      expect(map['durationSeconds'], 3600);
    });
  });
}
