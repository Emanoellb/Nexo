import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/plans/domain/plan_day_result.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';

// Quarta, 04/11/2026. Semana: domingo 01/11 a sábado 07/11.
const _today = LocalDate(2026, 11, 4);
const _sunday = LocalDate(2026, 11, 1);

PlanSnapshot _snapshot({
  PlanFrequency frequency = const DailyFrequency(),
  int goal = 90,
  Map<LocalDate, (int, bool)> days = const {},
  LocalDate start = _sunday,
  List<PlanPause> pauses = const [],
}) {
  final plan = Plan(
    id: 'p1',
    name: 'Concurso Banco Horizonte',
    startDate: start,
    endDate: start.addDays(60),
    frequency: frequency,
    dailyGoalMinutes: goal,
    pauses: pauses,
  );
  return PlanSnapshot(
    plan: plan,
    versions: [
      ScheduleVersion(
        effectiveFrom: start,
        frequency: frequency,
        dailyGoalMinutes: goal,
      ),
    ],
    days: [
      for (final MapEntry(key: day, value: (done, fin)) in days.entries)
        PlanDay(
          day: day,
          doneMinutes: done,
          finalizedAt: fin ? DateTime(2026, 11, 4, 22) : null,
        ),
    ],
  );
}

PlanDayStatus _status(PlanSnapshot s, LocalDate day) =>
    planDayResult(s, day, today: _today).status;

void main() {
  group('status e pontos do dia (lib, Conteúdo/05 e /06)', () {
    test('na meta = 5; com horas a mais = 7; com horas a menos = 3', () {
      final s = _snapshot(
        days: {
          _sunday: (90, false),
          _sunday.addDays(1): (120, false),
          _sunday.addDays(2): (70, true),
        },
      );
      expect(_status(s, _sunday), PlanDayStatus.met);
      expect(_status(s, _sunday.addDays(1)), PlanDayStatus.metOver);
      expect(_status(s, _sunday.addDays(2)), PlanDayStatus.metShort);
      expect(
        [
          for (final d in [0, 1, 2])
            planDayResult(s, _sunday.addDays(d), today: _today).points,
        ],
        [5, 7, 3],
      );
    });

    test('"com horas a mais" só a partir de 10 min acima da meta', () {
      final s = _snapshot(
        days: {
          _sunday: (99, false), // +9: na meta
          _sunday.addDays(1): (100, false), // +10: com horas a mais
        },
      );
      expect(_status(s, _sunday), PlanDayStatus.met);
      expect(_status(s, _sunday.addDays(1)), PlanDayStatus.metOver);
    });

    test('finalizou abaixo e estudou depois (RF16): o status sobe', () {
      final s = _snapshot(days: {_today: (95, true)});
      expect(_status(s, _today), PlanDayStatus.met);
    });

    test('dia passado sem meta e sem finalizar = não cumprido (0)', () {
      final s = _snapshot(days: {_sunday: (30, false)});
      final r = planDayResult(s, _sunday, today: _today);
      expect(r.status, PlanDayStatus.missed);
      expect(r.points, 0);
      expect(r.differenceMinutes, -60);
    });

    test('hoje abaixo da meta e sem finalizar = em andamento', () {
      final s = _snapshot(days: {_today: (70, false)});
      expect(_status(s, _today), PlanDayStatus.inProgress);
    });

    test('finalizar sem nenhum estudo não vale como "com horas a menos"', () {
      final s = _snapshot(days: {_today: (0, true)});
      expect(_status(s, _today), PlanDayStatus.inProgress);
    });

    test('folga: fora dos dias da semana, pausado e antes do início', () {
      // 1 = segunda … 7 = domingo; quarta (3) fora.
      final weekdays = _snapshot(frequency: WeekdaysFrequency({1, 5}));
      expect(_status(weekdays, _today), PlanDayStatus.off);
      expect(_status(weekdays, _sunday.addDays(1)), PlanDayStatus.missed);

      final paused = _snapshot(pauses: [PlanPause(start: _sunday.addDays(2))]);
      expect(_status(paused, _today), PlanDayStatus.off);

      final later = _snapshot(start: _today);
      expect(_status(later, _sunday), PlanDayStatus.off);
    });

    test('estudar na folga vale como dia normal ("estudo extra")', () {
      // Quarta fora dos dias escolhidos (segunda e sexta).
      final s = _snapshot(
        frequency: WeekdaysFrequency({1, 5}),
        days: {_today: (25, false), _sunday.addDays(2): (95, false)},
      );
      final today = planDayResult(s, _today, today: _today);
      expect(today.restDay, isTrue);
      expect(today.status, PlanDayStatus.inProgress);
      // Terça, também fora: cumprida, com pontos.
      expect(_status(s, _sunday.addDays(2)), PlanDayStatus.met);
    });

    test('folga sem estudo: próximo dia de estudo', () {
      final s = _snapshot(frequency: WeekdaysFrequency({1, 5}));
      expect(planDayResult(s, _today, today: _today).restDay, isTrue);
      // Quarta → sexta, 06/11.
      expect(nextStudyDay(s, today: _today), const LocalDate(2026, 11, 6));
      final paused = _snapshot(pauses: [PlanPause(start: _today)]);
      expect(nextStudyDay(paused, today: _today), isNull);
    });
  });

  group('"× por semana" = cota semanal (decisão de 05/11/2026)', () {
    test('dia sem estudo não vira "não cumprido"; hoje fica em andamento', () {
      final s = _snapshot(frequency: TimesPerWeekFrequency(2));
      expect(_status(s, _sunday), PlanDayStatus.off);
      expect(_status(s, _today), PlanDayStatus.inProgress);
    });

    test('cumprida a cota, os dias seguintes viram folga', () {
      final s = _snapshot(
        frequency: TimesPerWeekFrequency(2),
        days: {_sunday: (90, false), _sunday.addDays(1): (60, true)},
      );
      expect(_status(s, _sunday), PlanDayStatus.met);
      expect(_status(s, _sunday.addDays(1)), PlanDayStatus.metShort);
      // Cota 2 cumprida: hoje é folga.
      final today = planDayResult(s, _today, today: _today);
      expect(today.status, PlanDayStatus.off);
      expect(today.restDay, isTrue);
    });

    test('estudo depois da cota vale como dia normal', () {
      final s = _snapshot(
        frequency: TimesPerWeekFrequency(2),
        days: {
          _sunday: (90, false),
          _sunday.addDays(1): (60, true),
          _today: (100, false),
        },
      );
      final today = planDayResult(s, _today, today: _today);
      expect(today.restDay, isTrue);
      expect(today.status, PlanDayStatus.metOver);
      expect(planWeekPoints(s, _today, today: _today), 5 + 3 + 7);
    });

    test('dia com estudo abaixo da meta e sem finalizar não quebra', () {
      final s = _snapshot(
        frequency: TimesPerWeekFrequency(2),
        start: const LocalDate(2026, 10, 25),
        days: {
          const LocalDate(2026, 10, 26): (90, false),
          const LocalDate(2026, 10, 28): (90, false),
          _sunday: (90, false),
          _sunday.addDays(1): (20, false), // não cumprido, mas flexível
        },
      );
      expect(_status(s, _sunday.addDays(1)), PlanDayStatus.missed);
      expect(currentStreak(s, today: _today), 3);
    });
  });

  test('pontos da semana somam os dias (base do ajuste em users.points)', () {
    final s = _snapshot(
      days: {
        _sunday: (90, false),
        _sunday.addDays(1): (30, false),
        _sunday.addDays(2): (60, true),
      },
    );
    // 5 (na meta) + 0 (não cumprido) + 3 (com menos); hoje em andamento.
    expect(planWeekPoints(s, _today, today: _today), 8);
  });

  group('sequência atual', () {
    test('conta os cumpridos até hoje; não cumprido quebra', () {
      final s = _snapshot(
        start: _sunday.addDays(-7),
        days: {
          _sunday.addDays(-1): (10, false), // sábado: não cumprido
          _sunday: (90, false),
          _sunday.addDays(1): (100, false),
          _sunday.addDays(2): (60, true),
        },
      );
      // Hoje em andamento não conta nem quebra: dom, seg, ter.
      expect(currentStreak(s, today: _today), 3);
    });

    test('hoje cumprido entra na conta; folga não quebra', () {
      // Segunda (1), terça (2) e quarta (3) no plano; domingo de folga.
      final s = _snapshot(
        frequency: WeekdaysFrequency({1, 2, 3, 6}),
        start: _sunday.addDays(-1),
        days: {
          _sunday.addDays(-1): (90, false), // sábado
          _sunday.addDays(1): (90, false),
          _sunday.addDays(2): (90, false),
          _today: (95, false),
        },
      );
      expect(currentStreak(s, today: _today), 4);
    });

    test('sem estudo, zero', () {
      expect(currentStreak(_snapshot(), today: _today), 0);
    });

    test('"× por semana": semana fechada abaixo da cota quebra', () {
      // Cota 2. Semana de 18–24/10: 2 dias (cumpriu). Semana de 25–31/10:
      // só 1 (abaixo da cota). Esta semana: 1 até agora.
      final s = _snapshot(
        frequency: TimesPerWeekFrequency(2),
        start: const LocalDate(2026, 10, 18),
        days: {
          const LocalDate(2026, 10, 19): (90, false),
          const LocalDate(2026, 10, 21): (90, false),
          const LocalDate(2026, 10, 27): (90, false),
          _sunday.addDays(1): (90, false),
        },
      );
      // Só o dia desta semana: a anterior fechou com 1 de 2 e quebrou.
      expect(currentStreak(s, today: _today), 1);
    });

    test('"× por semana": semanas que bateram a cota somam', () {
      final s = _snapshot(
        frequency: TimesPerWeekFrequency(2),
        start: const LocalDate(2026, 10, 25),
        days: {
          const LocalDate(2026, 10, 26): (90, false),
          const LocalDate(2026, 10, 29): (90, false),
          _sunday.addDays(1): (90, false),
        },
      );
      // A semana atual ainda não fechou: não quebra mesmo com 1 de 2.
      expect(currentStreak(s, today: _today), 3);
    });
  });

  test('pontos totais do plano somam todas as semanas até hoje', () {
    final s = _snapshot(
      start: _sunday.addDays(-7),
      days: {
        _sunday.addDays(-3): (90, false), // 5
        _sunday.addDays(1): (100, false), // 7
        _sunday.addDays(2): (60, true), // 3
      },
    );
    expect(planTotalPoints(s, today: _today), 15);
  });
}
