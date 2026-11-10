import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../../../core/domain/local_date.dart';
import '../../auth/application/auth_providers.dart';
import '../../focus/domain/focus_session.dart';
import '../../plans/application/plan_today.dart';
import '../../plans/application/plans_providers.dart';
import '../../plans/domain/plan.dart';
import '../../plans/domain/plan_report.dart';
import '../../tasks/application/screen_now.dart';
import '../../tasks/application/task_actions.dart';
import '../data/achievements_repository.dart';
import '../domain/achievements.dart';

/// Na prototipação, o fake em memória; no bloco de integração, o Firestore.
/// Um por conta: trocar de conta recria.
final achievementsRepositoryProvider = Provider<AchievementsRepository>((ref) {
  ref.watch(currentUidProvider);
  final repository = FakeAchievementsRepository(
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final earnedAchievementsProvider = StreamProvider<List<EarnedAchievement>>(
  (ref) => ref.watch(achievementsRepositoryProvider).watchEarned(),
);

/// O que conta para cada critério, a partir dos dados da conta. `null`
/// enquanto carrega.
final achievementInputsProvider = Provider<AchievementInputs?>((ref) {
  final plans = ref.watch(plansProvider);
  final tasks = ref.watch(visibleTasksProvider);
  if (!plans.hasValue || !tasks.hasValue) return null;
  final today = LocalDate.fromDateTime(ref.watch(screenNowProvider));

  var focusSessions = 0;
  var metDays = 0;
  var longest = 0;
  var finished = 0;
  int? daysToFinish;
  for (final plan in plans.value!) {
    if (plan.status == PlanStatus.deleting) continue;
    final sessions = ref.watch(planSessionsProvider(plan.id));
    final snapshot = ref.watch(planSnapshotProvider(plan.id));
    if (!sessions.hasValue || snapshot == null) return null;
    focusSessions += sessions.value!
        .where((s) => s.source == SessionSource.focus)
        .length;
    // Até hoje (inclusive): o dia cumprido hoje já conta.
    final end = plan.endedOn ?? plan.endDate;
    if (!plan.startDate.isAfter(today)) {
      final report = planReport(
        snapshot,
        today: today,
        lastDay: end.isBefore(today) ? end : today,
      );
      metDays += report.metDays + report.metShortDays + report.metOverDays;
      if (report.longestStreak > longest) longest = report.longestStreak;
    }
    // Chegou ao fim do período (encerrar antes não conta).
    if (plan.status == PlanStatus.completed ||
        (plan.endedOn == null &&
            plan.status != PlanStatus.endedEarly &&
            plan.endDate.isBefore(today))) {
      finished++;
    } else if (plan.status == PlanStatus.active) {
      final left = today.daysUntil(plan.endDate) + 1;
      if (daysToFinish == null || left < daysToFinish) daysToFinish = left;
    }
  }
  return AchievementInputs(
    plans: plans.value!.length,
    focusSessions: focusSessions,
    metDays: metDays,
    longestStreak: longest,
    completedTasks: tasks.value!.where((t) => t.completed).length,
    finishedPlans: finished,
    daysToFinishPlan: daysToFinish,
  );
});

/// Uma medalha na tela: a definição, quando foi ganha (ou `null`) e quanto
/// falta.
class AchievementStatus {
  const AchievementStatus({
    required this.def,
    required this.earnedAt,
    required this.missing,
  });

  final AchievementDef def;
  final DateTime? earnedAt;
  final String? missing;

  bool get earned => earnedAt != null;
}

/// As 9 medalhas na ordem do catálogo. `null` enquanto carrega.
final achievementsViewProvider = Provider<List<AchievementStatus>?>((ref) {
  final earned = ref.watch(earnedAchievementsProvider);
  final inputs = ref.watch(achievementInputsProvider);
  if (!earned.hasValue || inputs == null) return null;
  final at = {for (final e in earned.value!) e.id: e.earnedAt};
  return [
    for (final def in NexoAchievements.catalog)
      AchievementStatus(
        def: def,
        earnedAt: at[def.id],
        missing: at.containsKey(def.id)
            ? null
            : NexoAchievements.missingText(def, inputs),
      ),
  ];
});

/// Grava as medalhas cujo critério foi atingido e que ainda não estão
/// gravadas (sem Cloud Functions: o app grava, contrato §4). Uma vez
/// ganha, não se perde. Escutado pelo shell das abas.
final achievementsKeeperProvider = Provider<void>((ref) {
  final earned = ref.watch(earnedAchievementsProvider);
  final inputs = ref.watch(achievementInputsProvider);
  if (!earned.hasValue || inputs == null) return;
  final have = {for (final e in earned.value!) e.id};
  final repository = ref.read(achievementsRepositoryProvider);
  for (final def in NexoAchievements.catalog) {
    if (!have.contains(def.id) && NexoAchievements.isMet(def, inputs)) {
      unawaited(repository.award(def.id));
    }
  }
});
