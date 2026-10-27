import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';

void main() {
  group('PlanFrequency (contrato do Firestore)', () {
    test('lê e grava os três tipos', () {
      for (final map in [
        {'type': 'daily'},
        {
          'type': 'weekdays',
          'weekdays': [1, 3, 5],
        },
        {'type': 'timesPerWeek', 'timesPerWeek': 3},
      ]) {
        expect(PlanFrequency.fromMap(map).toMap(), map);
      }
    });

    test('dias da semana fora de 1–7 ou vazios são recusados', () {
      expect(() => WeekdaysFrequency({0}), throwsArgumentError);
      expect(() => WeekdaysFrequency({8}), throwsArgumentError);
      expect(() => WeekdaysFrequency({}), throwsArgumentError);
      expect(() => TimesPerWeekFrequency(8), throwsArgumentError);
    });

    test('tipo desconhecido é erro de formato', () {
      expect(
        () => PlanFrequency.fromMap({'type': 'monthly'}),
        throwsFormatException,
      );
    });

    test(
      'dia na frequência: diário e dias da semana; × por semana pendente',
      () {
        const monday = LocalDate(2026, 10, 26);
        const tuesday = LocalDate(2026, 10, 27);
        expect(isScheduledWeekday(const DailyFrequency(), tuesday), isTrue);
        final mwf = WeekdaysFrequency({1, 3, 5});
        expect(isScheduledWeekday(mwf, monday), isTrue);
        expect(isScheduledWeekday(mwf, tuesday), isFalse);
        expect(isScheduledWeekday(TimesPerWeekFrequency(3), monday), isNull);
      },
    );
  });

  group('versão vigente (RF04)', () {
    final v1 = ScheduleVersion(
      effectiveFrom: const LocalDate(2026, 10, 1),
      frequency: const DailyFrequency(),
      dailyGoalMinutes: 90,
    );
    final v2 = ScheduleVersion(
      effectiveFrom: const LocalDate(2026, 10, 15),
      frequency: WeekdaysFrequency({1, 2, 3, 4, 5}),
      dailyGoalMinutes: 120,
    );

    test('usa a de effectiveFrom mais recente ≤ dia, em qualquer ordem', () {
      expect(versionFor([v2, v1], const LocalDate(2026, 10, 14)), v1);
      expect(versionFor([v2, v1], const LocalDate(2026, 10, 15)), v2);
      expect(versionFor([v1, v2], const LocalDate(2026, 12, 1)), v2);
    });

    test('antes da primeira versão não há meta', () {
      expect(versionFor([v1, v2], const LocalDate(2026, 9, 30)), isNull);
    });

    test('mudança vale amanhã, ou no início se o plano não começou', () {
      const today = LocalDate(2026, 10, 26);
      expect(
        nextEffectiveFrom(
          today: today,
          planStart: const LocalDate(2026, 10, 1),
        ),
        const LocalDate(2026, 10, 27),
      );
      expect(
        nextEffectiveFrom(
          today: today,
          planStart: const LocalDate(2026, 11, 3),
        ),
        const LocalDate(2026, 11, 3),
      );
    });
  });

  group('pausa (RF05)', () {
    test('vale do dia em que começa até o dia anterior ao de retomar', () {
      const pause = PlanPause(
        start: LocalDate(2026, 10, 20),
        end: LocalDate(2026, 10, 23),
      );
      expect(pause.covers(const LocalDate(2026, 10, 19)), isFalse);
      expect(pause.covers(const LocalDate(2026, 10, 20)), isTrue);
      expect(pause.covers(const LocalDate(2026, 10, 22)), isTrue);
      expect(pause.covers(const LocalDate(2026, 10, 23)), isFalse);
    });

    test('pausa em aberto cobre todos os dias a partir do início', () {
      const pauses = [PlanPause(start: LocalDate(2026, 10, 24))];
      expect(isPausedOn(pauses, const LocalDate(2027, 1, 1)), isTrue);
      expect(isPausedOn(pauses, const LocalDate(2026, 10, 23)), isFalse);
    });
  });

  group('período do plano (RF06)', () {
    const start = LocalDate(2026, 10, 1);
    const end = LocalDate(2026, 12, 31);

    test('dentro de início e fim, inclusive', () {
      expect(
        isWithinPlanPeriod(day: start, startDate: start, endDate: end),
        isTrue,
      );
      expect(
        isWithinPlanPeriod(day: end, startDate: start, endDate: end),
        isTrue,
      );
      expect(
        isWithinPlanPeriod(
          day: start.addDays(-1),
          startDate: start,
          endDate: end,
        ),
        isFalse,
      );
    });

    test('encerrado antes: vale até endedOn', () {
      const endedOn = LocalDate(2026, 11, 10);
      expect(
        isWithinPlanPeriod(
          day: endedOn,
          startDate: start,
          endDate: end,
          endedOn: endedOn,
        ),
        isTrue,
      );
      expect(
        isWithinPlanPeriod(
          day: endedOn.addDays(1),
          startDate: start,
          endDate: end,
          endedOn: endedOn,
        ),
        isFalse,
      );
    });
  });
}
