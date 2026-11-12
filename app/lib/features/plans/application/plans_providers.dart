import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../../auth/application/auth_providers.dart';
import '../../focus/domain/focus_session.dart';
import '../../../core/data/firestore_access.dart';
import '../data/firestore_plans_repository.dart';
import '../data/plans_repository.dart';
import '../domain/plan.dart';
import '../domain/plan_schedule.dart';

/// Firestore (`users/{uid}/…`), com o uid verificado: sem login ou antes de
/// verificar o e-mail, listas vazias. Trocar de conta recria.
/// Ao criar, retoma uma exclusão de plano que ficou no meio.
final plansRepositoryProvider = Provider<PlansRepository>(
  (ref) => FirestorePlansRepository(
    ref.watch(firestoreAccessProvider),
    uid: ref.watch(verifiedUidProvider),
    clock: ref.watch(clockProvider),
  )..resumeDeletionsInBackground(),
);

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
