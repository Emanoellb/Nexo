import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/app/prototype/sample_data.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/features/goals/application/goals_providers.dart';
import 'package:nexo/features/plans/application/plans_providers.dart';
import 'package:nexo/features/subjects/application/subjects_providers.dart';
import 'package:nexo/features/tasks/application/tasks_providers.dart';

Future<ProviderContainer> _seeded(DateTime now) async {
  final container = ProviderContainer(
    overrides: [clockProvider.overrideWithValue(() => now)],
  );
  addTearDown(container.dispose);
  await container.read(prototypeSampleDataProvider.future);
  return container;
}

void main() {
  test('dados de exemplo válidos, coerentes e relativos a hoje', () async {
    final container = await _seeded(DateTime(2026, 10, 26, 12));
    final plans = container.read(plansRepositoryProvider);

    final planList = await plans.watchPlans().first;
    expect(planList.map((p) => p.name), [
      'Concurso Banco Horizonte',
      'Inglês para intercâmbio',
    ]);

    final concurso = planList.first;
    final days = await plans.watchDays(concurso.id).first;
    final sessions = await plans.watchSessions(concurso.id).first;
    // doneMinutes de cada dia = soma das sessões do dia.
    for (final day in days) {
      final seconds = sessions
          .where((s) => s.day == day.day)
          .fold<int>(0, (sum, s) => sum + s.durationSeconds);
      expect(day.doneMinutes, seconds ~/ 60, reason: day.day.toIso());
    }
    // Hoje: 60 de 90 min (a manhã já passou ao meio-dia).
    expect(days.last.day.toIso(), '2026-10-26');
    expect(days.last.doneMinutes, 60);

    expect(
      await container.read(subjectsRepositoryProvider).watchSubjects().first,
      hasLength(2),
    );
    expect(
      await container.read(goalsRepositoryProvider).watchGoals().first,
      hasLength(1),
    );

    final tasks = await container
        .read(tasksRepositoryProvider)
        .watchTasks()
        .first;
    expect(tasks, hasLength(5));
    expect(
      tasks.where((t) => t.isOverdue(DateTime(2026, 10, 26, 12))),
      hasLength(1),
    );
    expect(tasks.last.completed, isTrue);
  });

  test('cedo de manhã, ainda sem a sessão de hoje', () async {
    final container = await _seeded(DateTime(2026, 10, 26, 7));
    final plans = container.read(plansRepositoryProvider);
    final concurso = (await plans.watchPlans().first).first;
    final days = await plans.watchDays(concurso.id).first;
    expect(days.any((d) => d.day.toIso() == '2026-10-26'), isFalse);
  });

  test('só nomes de instituições fictícios', () async {
    final container = await _seeded(DateTime(2026, 10, 26, 12));
    final texts = [
      for (final p
          in await container.read(plansRepositoryProvider).watchPlans().first)
        p.name,
      for (final g
          in await container.read(goalsRepositoryProvider).watchGoals().first)
        g.name,
      for (final t
          in await container.read(tasksRepositoryProvider).watchTasks().first)
        t.title,
    ].join(' ');
    for (final real in [
      'Banco do Brasil',
      'Caixa',
      'USP',
      'Unicamp',
      'ENEM',
      'Fuvest',
    ]) {
      expect(texts.contains(real), isFalse, reason: real);
    }
  });
}
