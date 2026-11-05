import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/app/prototype/sample_data.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/data/fake_auth_repository.dart';
import 'package:nexo/features/auth/domain/auth_user.dart';
import 'package:nexo/features/goals/application/goals_providers.dart';
import 'package:nexo/features/plans/application/plans_providers.dart';
import 'package:nexo/features/subjects/application/subjects_providers.dart';
import 'package:nexo/features/tasks/application/tasks_providers.dart';

/// Conta de protótipo logada (os exemplos são só dela) e semeadura ligada,
/// como no `main`.
Future<ProviderContainer> _seeded(DateTime now) async {
  final container = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(() => now),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
      prototypeSeedingProvider.overrideWithValue(true),
    ],
  );
  addTearDown(container.dispose);
  await _seedFor(container);
  return container;
}

/// Ouve os providers como o `main` (no Riverpod 3, provider sem ouvinte fica
/// pausado) e espera a sessão e a semeadura.
Future<void> _seedFor(ProviderContainer container) async {
  container
    ..listen(authStateProvider, (_, _) {})
    ..listen(prototypeSampleDataProvider, (_, _) {});
  await container.read(authStateProvider.future);
  await container.read(prototypeSampleDataProvider.future);
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

    // Pontos do perfil = o que foi semeado: dias de 5 a 2 atrás (com menos
    // 3, com mais 7, com menos 3, na meta 5) + 1 tarefa concluída.
    final profile = await container
        .read(userProfileRepositoryProvider)
        .watchProfile(FakeAuthRepository.prototypeUser.uid)
        .first;
    expect(profile!.points, 3 + 7 + 3 + 5 + 1);
  });

  test('conta nova começa vazia; a de protótipo é o plano principal', () async {
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 26, 12)),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            initialUser: const AuthUser(
              uid: 'conta-nova',
              emailVerified: true,
              email: 'nova@email.com',
            ),
          ),
        ),
        prototypeSeedingProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    await _seedFor(container);
    expect(
      await container.read(plansRepositoryProvider).watchPlans().first,
      isEmpty,
    );
    expect(
      await container.read(tasksRepositoryProvider).watchTasks().first,
      isEmpty,
    );

    final ana = await _seeded(DateTime(2026, 10, 26, 12));
    final concurso =
        (await ana.read(plansRepositoryProvider).watchPlans().first).first;
    final profile = await ana
        .read(userProfileRepositoryProvider)
        .watchProfile(FakeAuthRepository.prototypeUser.uid)
        .first;
    expect(profile!.primaryPlanId, concurso.id);
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
