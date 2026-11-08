import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/local_date.dart';
import '../../tasks/application/screen_now.dart';
import '../domain/plan.dart';
import '../domain/plan_day_result.dart';
import '../domain/plan_schedule.dart';
import 'plans_providers.dart';

/// Um plano hoje (cartão `Nexo/PlanCard`, no Início e na Visão geral).
@immutable
class PlanToday {
  const PlanToday({
    required this.plan,
    required this.today,
    required this.dayNumber,
    required this.totalDays,
    required this.streak,
    this.nextStudyDay,
    this.otherActivePlans = false,
  });

  final Plan plan;
  final PlanDayResult today;

  /// "Dia X de N"; `dayNumber` fora de 1..N quando hoje está fora do
  /// período.
  final int dayNumber;
  final int totalDays;
  final int streak;

  /// Próximo dia com atividade ("Próximo: seg, 10/11" na folga).
  final LocalDate? nextStudyDay;

  /// Há outro plano ativo para escolher como principal (plano principal
  /// arquivado ou encerrado).
  final bool otherActivePlans;

  /// Pausado agora: a pausa em aberto (sem fim).
  PlanPause? get openPause =>
      plan.pauses.where((p) => p.end == null).lastOrNull;

  bool get isPaused => plan.status == PlanStatus.paused || openPause != null;

  /// Arquivado ou encerrado (antes do fim, no fim ou com o período já
  /// passado; ver [Plan.isFinished]): o Início pede para escolher outro
  /// principal ou criar um. Nada é promovido sozinho.
  bool get isClosed =>
      plan.status == PlanStatus.archived || plan.isFinished(today.day);
}

/// Monta o [PlanToday] de [snapshot] em [today].
PlanToday planTodayOf(
  PlanSnapshot snapshot, {
  required LocalDate today,
  required int streak,
  bool otherActivePlans = false,
}) {
  final plan = snapshot.plan;
  final result = planDayResult(snapshot, today, today: today);
  return PlanToday(
    plan: plan,
    today: result,
    dayNumber: plan.startDate.daysUntil(today) + 1,
    totalDays: plan.startDate.daysUntil(plan.endDate) + 1,
    streak: streak,
    nextStudyDay: result.restDay ? nextStudyDay(snapshot, today: today) : null,
    otherActivePlans: otherActivePlans,
  );
}

/// O que o cálculo do plano precisa, lido dos repositórios. `null`
/// enquanto carrega ou se o plano não existe mais.
final planSnapshotProvider = Provider.family<PlanSnapshot?, String>((
  ref,
  planId,
) {
  final plan = ref.watch(planProvider(planId)).value;
  final versions = ref.watch(planVersionsProvider(planId));
  final days = ref.watch(planDaysProvider(planId));
  if (plan == null || !versions.hasValue || !days.hasValue) return null;
  return PlanSnapshot(plan: plan, versions: versions.value!, days: days.value!);
});

/// Sequência do plano, à parte: só refaz quando o plano, as versões, os
/// dias ou o "agora" mudam (não a cada toque numa tarefa). `null` enquanto
/// carrega.
final planStreakProvider = Provider.family<int?, String>((ref, planId) {
  final snapshot = ref.watch(planSnapshotProvider(planId));
  if (snapshot == null) return null;
  final today = LocalDate.fromDateTime(ref.watch(screenNowProvider));
  return currentStreak(snapshot, today: today);
});

/// O plano hoje, para a Visão geral. `null` enquanto carrega.
final planTodayProvider = Provider.family<PlanToday?, String>((ref, planId) {
  final snapshot = ref.watch(planSnapshotProvider(planId));
  final streak = ref.watch(planStreakProvider(planId));
  if (snapshot == null || streak == null) return null;
  final today = LocalDate.fromDateTime(ref.watch(screenNowProvider));
  return planTodayOf(snapshot, today: today, streak: streak);
});
