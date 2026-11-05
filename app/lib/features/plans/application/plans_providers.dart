import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../../auth/application/auth_providers.dart';
import '../../focus/domain/focus_session.dart';
import '../data/fake_plans_repository.dart';
import '../data/plans_repository.dart';
import '../domain/plan.dart';
import '../domain/plan_schedule.dart';

/// Na prototipação, o fake em memória; no bloco de integração, o Firestore.
/// Um por conta: trocar de conta recria (dados de `users/{uid}`).
final plansRepositoryProvider = Provider<PlansRepository>((ref) {
  ref.watch(currentUidProvider);
  final repository = FakePlansRepository(clock: ref.watch(clockProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

final plansProvider = StreamProvider<List<Plan>>(
  (ref) => ref.watch(plansRepositoryProvider).watchPlans(),
);

final planProvider = StreamProvider.family<Plan?, String>(
  (ref, planId) => ref.watch(plansRepositoryProvider).watchPlan(planId),
);

final planVersionsProvider =
    StreamProvider.family<List<ScheduleVersion>, String>(
      (ref, planId) => ref.watch(plansRepositoryProvider).watchVersions(planId),
    );

final planTopicsProvider = StreamProvider.family<List<PlanTopic>, String>(
  (ref, planId) => ref.watch(plansRepositoryProvider).watchTopics(planId),
);

final planDaysProvider = StreamProvider.family<List<PlanDay>, String>(
  (ref, planId) => ref.watch(plansRepositoryProvider).watchDays(planId),
);

final planSessionsProvider = StreamProvider.family<List<FocusSession>, String>(
  (ref, planId) => ref.watch(plansRepositoryProvider).watchSessions(planId),
);
