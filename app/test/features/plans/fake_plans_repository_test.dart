import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/focus/domain/focus_session.dart';
import 'package:nexo/features/focus/domain/session_split.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';

import '../../fakes/fakes.dart';

final _now = DateTime(2026, 10, 26, 12);
const _today = LocalDate(2026, 10, 26);

Future<(FakePlansRepository, Plan)> _withPlan() async {
  final repo = FakePlansRepository(clock: () => _now);
  addTearDown(repo.dispose);
  final plan = await repo.createPlan(
    Plan(
      id: '',
      name: 'Concurso Banco Horizonte',
      startDate: _today.addDays(-20),
      endDate: _today.addDays(100),
      frequency: const DailyFrequency(),
      dailyGoalMinutes: 90,
    ),
    topics: [
      (name: 'Porcentagem', subjectId: null),
      (name: 'Juros simples', subjectId: null),
    ],
  );
  return (repo, plan);
}

List<DaySegment> _segments(DateTime start, Duration length) =>
    splitSessionByDay([ActiveInterval(start, start.add(length))]);

void main() {
  test(
    'criar plano grava a versão inicial e os tópicos no mesmo lote',
    () async {
      final (repo, plan) = await _withPlan();
      expect(plan.id, isNotEmpty);

      final versions = await repo.watchVersions(plan.id).first;
      expect(versions.single.effectiveFrom, plan.startDate);
      expect(versions.single.dailyGoalMinutes, 90);

      final topics = await repo.watchTopics(plan.id).first;
      expect(topics.map((t) => t.name), ['Porcentagem', 'Juros simples']);
    },
  );

  test('nova versão atualiza a cópia da meta no plano', () async {
    final (repo, plan) = await _withPlan();
    await repo.addScheduleVersion(
      plan.id,
      ScheduleVersion(
        effectiveFrom: _today.addDays(1),
        frequency: WeekdaysFrequency({1, 2, 3, 4, 5}),
        dailyGoalMinutes: 120,
      ),
    );
    expect((await repo.watchPlan(plan.id).first)!.dailyGoalMinutes, 120);
    expect(await repo.watchVersions(plan.id).first, hasLength(2));
  });

  test('sessão soma o doneMinutes do dia (mesmo lote)', () async {
    final (repo, plan) = await _withPlan();
    await repo.addSessions(
      plan.id,
      _segments(DateTime(2026, 10, 26, 8), const Duration(minutes: 40)),
      source: SessionSource.focus,
    );
    await repo.addSessions(
      plan.id,
      _segments(DateTime(2026, 10, 26, 10), const Duration(minutes: 20)),
      source: SessionSource.manual,
    );
    final days = await repo.watchDays(plan.id).first;
    expect(days.single.day, _today);
    expect(days.single.doneMinutes, 60);
  });

  test('sessão que passa da meia-noite soma em dois dias', () async {
    final (repo, plan) = await _withPlan();
    await repo.addSessions(
      plan.id,
      _segments(DateTime(2026, 10, 24, 23, 30), const Duration(minutes: 75)),
      source: SessionSource.focus,
    );
    final days = await repo.watchDays(plan.id).first;
    expect(days.map((d) => (d.day.toIso(), d.doneMinutes)), [
      ('2026-10-24', 30),
      ('2026-10-25', 45),
    ]);
  });

  test('fora da janela de 7 dias é recusado', () async {
    final (repo, plan) = await _withPlan();
    await expectLater(
      repo.addSessions(
        plan.id,
        _segments(DateTime(2026, 10, 18, 9), const Duration(minutes: 30)),
        source: SessionSource.manual,
      ),
      throwsStateError,
    );
  });

  test('apagar sessão desconta do dia', () async {
    final (repo, plan) = await _withPlan();
    final created = await repo.addSessions(
      plan.id,
      _segments(DateTime(2026, 10, 26, 8), const Duration(minutes: 40)),
      source: SessionSource.focus,
    );
    await repo.deleteSession(plan.id, created.single.id);
    expect((await repo.watchDays(plan.id).first).single.doneMinutes, 0);
  });

  test('finalizar e desfazer o dia', () async {
    final (repo, plan) = await _withPlan();
    await repo.finalizeDay(plan.id, _today);
    expect((await repo.watchDays(plan.id).first).single.isFinalized, isTrue);
    await repo.undoFinalizeDay(plan.id, _today);
    final day = (await repo.watchDays(plan.id).first).single;
    expect(day.isFinalized, isFalse);
    // Contrato das regras v0.8: o campo fica, com null (não é apagado).
    expect(day.toMap(), containsPair('finalizedAt', null));
  });

  test('desfazer o dia também respeita a janela de 7 dias', () async {
    var now = _now;
    final repo = FakePlansRepository(clock: () => now);
    addTearDown(repo.dispose);
    final plan = await repo.createPlan(
      Plan(
        id: '',
        name: 'Concurso Banco Horizonte',
        startDate: _today.addDays(-20),
        endDate: _today.addDays(100),
        frequency: const DailyFrequency(),
        dailyGoalMinutes: 90,
      ),
    );
    final day = _today.addDays(-6);
    await repo.finalizeDay(plan.id, day);

    // Dois dias depois, o dia saiu da janela.
    now = _now.add(const Duration(days: 2));
    await expectLater(repo.undoFinalizeDay(plan.id, day), throwsStateError);
    expect((await repo.watchDays(plan.id).first).single.isFinalized, isTrue);
  });

  test('a lista avisa quem escuta quando um plano muda', () async {
    final (repo, plan) = await _withPlan();
    final emitted = <String>[];
    final sub = repo.watchPlans().listen(
      (plans) => emitted.add(plans.single.name),
    );
    await Future<void>.delayed(Duration.zero);
    await repo.updatePlan(plan.copyWith(name: 'Concurso Horizonte 2027'));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(emitted, ['Concurso Banco Horizonte', 'Concurso Horizonte 2027']);
  });
}
