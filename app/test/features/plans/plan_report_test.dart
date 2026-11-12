import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/plans/domain/plan_day_result.dart';
import 'package:nexo/features/plans/domain/plan_report.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';
import 'package:nexo/features/plans/application/plans_view.dart';
import 'package:nexo/features/plans/presentation/plan_list_item.dart';
import 'package:nexo/features/plans/presentation/plan_text.dart';

import 'plan_seed.dart';

import '../../fakes/fakes.dart';

void main() {
  late FakePlansRepository repo;

  setUp(() {
    repo = FakePlansRepository(clock: () => seedNow);
    addTearDown(repo.dispose);
  });

  Future<PlanSnapshot> snapshot(String planId) async => PlanSnapshot(
    plan: (await repo.watchPlan(planId).first)!,
    versions: await repo.watchVersions(planId).first,
    days: await repo.watchDays(planId).first,
  );

  test(
    'até ontem: horas, saldo, dias por situação, sequências e pontos',
    () async {
      final seed = await seedPlanHistory(repo);
      final r = planReport(await snapshot(seed.plan.id), today: seedToday);
      expect(r.plannedMinutes, 600);
      expect(r.doneMinutes, 225);
      expect(r.balanceMinutes, -375);
      expect(signedMinutes(r.balanceMinutes), '−6h 15min');
      expect(r.metDays, 2);
      expect(r.metOverDays, 1);
      expect(r.metShortDays, 1);
      expect(r.missedDays, 6);
      expect(r.offDays, 0);
      expect(r.longestStreak, 3);
      expect(r.currentStreak, 0);
      expect(r.points, 5 + 7 + 3 + 5);
      expect(r.activeDays, 4);
      expect(r.averageMinutes, 56);
    },
  );

  test(
    'horas por tópico: a sessão divide igualmente entre os tópicos',
    () async {
      final seed = await seedPlanHistory(repo);
      final sessions = await repo.watchSessions(seed.plan.id).first;
      final minutes = topicMinutes(sessions);
      // 60 + 75/2 e 75/2 + 60.
      expect(minutes[seed.porcentagem], 97);
      expect(minutes[seed.juros], 97);
    },
  );

  test('relatório do plano encerrado vai até o fim (endedOn)', () async {
    final seed = await seedPlanHistory(repo);
    await repo.updatePlan(
      seed.plan.copyWith(
        status: PlanStatus.endedEarly,
        endedOn: () => const LocalDate(2026, 10, 31),
      ),
    );
    final r = planReport(await snapshot(seed.plan.id), today: seedToday);
    // 25/10 a 31/10: 7 dias; 4 não cumpridos e 3 cumpridos.
    expect(r.countedDays, 7);
    expect(r.fulfilledDays, 3);
  });

  test('regra única de encerrado e a linha da lista', () async {
    final seed = await seedPlanHistory(repo);
    final plan = seed.plan;
    // Fim já passado, mesmo ativo: encerrado (lista, detalhe e menu).
    final past = plan.copyWith(endDate: seedToday.addDays(-1));
    expect(past.isFinished(seedToday), isTrue);
    expect(planGroupOf(past, today: seedToday), PlanGroup.ended);
    expect(plan.isFinished(seedToday), isFalse);

    // "× por semana" que ainda não começou: "Começa em", sem barra.
    final future = Plan(
      id: 'f',
      name: 'Leitura',
      startDate: const LocalDate(2026, 11, 10),
      endDate: const LocalDate(2027, 1, 10),
      frequency: TimesPerWeekFrequency(4),
      dailyGoalMinutes: 30,
    );
    final item = planListItem(
      PlanSnapshot(plan: future, versions: const [], days: const []),
      today: seedToday,
    );
    expect(item.value, 'Começa em 10/11/2026');
    expect(item.progress, isNull);
  });

  test('versão nova no mesmo dia vale sobre a anterior', () {
    const day = LocalDate(2026, 12, 1);
    final first = ScheduleVersion(
      effectiveFrom: day,
      frequency: const DailyFrequency(),
      dailyGoalMinutes: 60,
    );
    final second = ScheduleVersion(
      effectiveFrom: day,
      frequency: const DailyFrequency(),
      dailyGoalMinutes: 90,
    );
    expect(versionFor([first, second], day)!.dailyGoalMinutes, 90);
  });

  test('textos do plano', () {
    expect(frequencyText(const DailyFrequency()), 'Todos os dias');
    expect(
      frequencyText(WeekdaysFrequency({1, 2, 3, 4, 5})),
      'Segunda a sexta',
    );
    expect(
      frequencyText(WeekdaysFrequency({1, 3, 5})),
      'Segunda, quarta e sexta',
    );
    expect(frequencyText(TimesPerWeekFrequency(4)), '4× por semana');
    expect(reminderBeforeLabel(0), 'Na hora');
    expect(reminderBeforeLabel(60), '1 h antes');
    expect(goalDeadlineShort(const LocalDate(2027, 7, 31)), 'Até jul/2027');
    expect(
      goalDeadlineLong(const LocalDate(2027, 7, 31)),
      'Prazo: julho de 2027',
    );
    expect(monthTitle(2026, 11), 'Novembro de 2026');
    expect(dayTitle(const LocalDate(2026, 11, 5)), 'Qui, 5 de novembro');
    expect(PlanDayStatus.met.points, 5);
  });
}
