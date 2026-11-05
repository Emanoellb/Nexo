import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/data/fake_auth_repository.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';
import 'package:nexo/features/progress/application/progress_actions.dart';
import 'package:nexo/features/tasks/application/tasks_providers.dart';
import 'package:nexo/features/tasks/domain/task.dart';

const _today = LocalDate(2026, 11, 4);
final _now = DateTime(2026, 11, 4, 20);

/// Conta de protótipo logada, perfil com 0 pontos e sem plano principal.
Future<ProviderContainer> _container() async {
  final container = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(() => _now),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
    ],
  );
  addTearDown(container.dispose);
  container
    ..listen(authStateProvider, (_, _) {})
    ..listen(userProfileProvider, (_, _) {});
  await container.read(authStateProvider.future);
  await container.read(userProfileProvider.future);
  return container;
}

Future<({int points, String? primary})> _profile(ProviderContainer c) async {
  final p = await c
      .read(userProfileRepositoryProvider)
      .watchProfile(FakeAuthRepository.prototypeUser.uid)
      .first;
  return (points: p!.points, primary: p.primaryPlanId);
}

Plan _draft(String name, {int goal = 90}) => Plan(
  id: '',
  name: name,
  startDate: _today.addDays(-3),
  endDate: _today.addDays(60),
  frequency: const DailyFrequency(),
  dailyGoalMinutes: goal,
);

void main() {
  test('o primeiro plano criado vira o principal; o segundo não', () async {
    final c = await _container();
    final actions = c.read(progressActionsProvider);
    // Em seguida, sem esperar o perfil propagar.
    final first = await actions.createPlan(_draft('Concurso Banco Horizonte'));
    await actions.createPlan(_draft('Inglês para intercâmbio'));
    expect((await _profile(c)).primary, first.id);
  });

  test('sessão que bate a meta soma 5; passar da meta, 7', () async {
    final c = await _container();
    final actions = c.read(progressActionsProvider);
    final plan = await actions.createPlan(_draft('Concurso Banco Horizonte'));

    await actions.addFocusMinutes(plan.id, 60);
    expect((await _profile(c)).points, 0); // 60 de 90: em andamento

    await actions.addFocusMinutes(plan.id, 30);
    expect((await _profile(c)).points, 5); // na meta

    await actions.addFocusMinutes(plan.id, 25);
    expect((await _profile(c)).points, 7); // com horas a mais
  });

  test('toques simultâneos não contam os pontos em dobro', () async {
    final c = await _container();
    final actions = c.read(progressActionsProvider);
    final plan = await actions.createPlan(_draft('Concurso Banco Horizonte'));
    await actions.addFocusMinutes(plan.id, 60);

    // Dois "Focar" ao mesmo tempo: 60 + 25 + 25 = 110 min, com horas a mais.
    await Future.wait([
      actions.addFocusMinutes(plan.id, 25),
      actions.addFocusMinutes(plan.id, 25),
    ]);
    expect((await _profile(c)).points, 7);
  });

  test('finalizar abaixo da meta soma 3; desfazer tira os 3', () async {
    final c = await _container();
    final actions = c.read(progressActionsProvider);
    final plan = await actions.createPlan(_draft('Concurso Banco Horizonte'));
    await actions.addFocusMinutes(plan.id, 70);

    await actions.finalizeDay(plan.id, _today);
    expect((await _profile(c)).points, 3);

    await actions.undoFinalizeDay(plan.id, _today);
    expect((await _profile(c)).points, 0);
  });

  test('tarefa: +1 ao concluir, −1 ao reabrir; nunca abaixo de 0', () async {
    final c = await _container();
    final actions = c.read(progressActionsProvider);
    final task = await c
        .read(tasksRepositoryProvider)
        .createTask(NexoTask(id: '', title: 'Lista de exercícios 3'));

    await actions.setTaskCompleted(task.id, true);
    expect((await _profile(c)).points, 1);
    await actions.setTaskCompleted(task.id, false);
    expect((await _profile(c)).points, 0);
    await actions.setTaskCompleted(task.id, false);
    expect((await _profile(c)).points, 0);
  });
}
