import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/data/fake_auth_repository.dart';
import 'package:nexo/features/goals/application/goal_actions.dart';
import 'package:nexo/features/plans/application/plans_providers.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/progress/application/progress_actions.dart';

import 'plan_seed.dart';

Future<ProviderContainer> _container() async {
  final c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(() => seedNow),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
    ],
  );
  addTearDown(c.dispose);
  c.listen(authStateProvider, (_, _) {});
  await c.read(authStateProvider.future);
  return c;
}

Future<Plan> _plan(ProviderContainer c, String id) async =>
    (await c.read(plansRepositoryProvider).watchPlan(id).first)!;

Future<String?> _primary(ProviderContainer c) async =>
    (await c
            .read(userProfileRepositoryProvider)
            .watchProfile(FakeAuthRepository.prototypeUser.uid)
            .first)
        ?.primaryPlanId;

void main() {
  test('pausar vale a partir de hoje; Desfazer tira a pausa', () async {
    final c = await _container();
    final seed = await seedPlanHistory(c.read(plansRepositoryProvider));
    final progress = c.read(progressActionsProvider);

    await progress.pausePlan(seed.plan.id);
    var plan = await _plan(c, seed.plan.id);
    expect(plan.status, PlanStatus.paused);
    expect(plan.pauses.single.start, seedToday);
    expect(plan.pauses.single.end, isNull);

    await progress.undoPausePlan(seed.plan.id);
    plan = await _plan(c, seed.plan.id);
    expect(plan.status, PlanStatus.active);
    expect(plan.pauses, isEmpty);
  });

  test('encerrar antes grava endedOn hoje; arquivar tem Desfazer', () async {
    final c = await _container();
    final seed = await seedPlanHistory(c.read(plansRepositoryProvider));
    final progress = c.read(progressActionsProvider);

    await progress.endPlanEarly(seed.plan.id);
    var plan = await _plan(c, seed.plan.id);
    expect(plan.status, PlanStatus.endedEarly);
    expect(plan.endedOn, seedToday);

    await progress.archivePlan(seed.plan.id);
    expect((await _plan(c, seed.plan.id)).status, PlanStatus.archived);
    await progress.unarchivePlan(seed.plan.id, PlanStatus.endedEarly);
    plan = await _plan(c, seed.plan.id);
    expect(plan.status, PlanStatus.endedEarly);
    expect(plan.endedOn, seedToday);
  });

  test('encerrar plano pausado: a pausa cobre o dia do encerramento', () async {
    final c = await _container();
    final seed = await seedPlanHistory(c.read(plansRepositoryProvider));
    final progress = c.read(progressActionsProvider);
    await progress.pausePlan(seed.plan.id);
    await progress.endPlanEarly(seed.plan.id);
    final plan = await _plan(c, seed.plan.id);
    expect(plan.endedOn, seedToday);
    // O fim da pausa não entra nela: hoje (endedOn) continua pausado.
    expect(plan.pauses.single.covers(seedToday), isTrue);
  });

  test('excluir o principal limpa o principal e apaga os filhos', () async {
    final c = await _container();
    final repo = c.read(plansRepositoryProvider);
    final seed = await seedPlanHistory(repo);
    final progress = c.read(progressActionsProvider);
    await progress.setPrimaryPlan(seed.plan.id);
    expect(await _primary(c), seed.plan.id);

    await progress.deletePlan(seed.plan.id);
    expect(await _primary(c), isNull);
    expect(await repo.watchPlans().first, isEmpty);
    expect(await repo.watchSessions(seed.plan.id).first, isEmpty);
    expect(await repo.watchTopics(seed.plan.id).first, isEmpty);
  });

  test('objetivo: ligar muda de objetivo; Desfazer volta; excluir solta os '
      'planos', () async {
    final c = await _container();
    final goals = c.read(goalActionsProvider);
    final a = await goals.create(name: 'Intercâmbio em Dublin');
    final b = await goals.create(name: 'Passar no Concurso Horizonte');
    final seed = await seedPlanHistory(
      c.read(plansRepositoryProvider),
      goalId: b.id,
    );

    final before = await goals.linkPlans(a.id, [seed.plan.id]);
    expect((await _plan(c, seed.plan.id)).goalId, a.id);
    await goals.restoreGoals(before);
    expect((await _plan(c, seed.plan.id)).goalId, b.id);

    await goals.delete(b.id);
    expect((await _plan(c, seed.plan.id)).goalId, isNull);
  });
}
