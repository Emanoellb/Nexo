import 'package:flutter/foundation.dart';

import '../../../core/domain/local_date.dart';
import '../../../core/format/duration_text.dart';
import '../domain/plan.dart';
import '../domain/plan_day_result.dart';
import '../domain/plan_schedule.dart';
import 'plan_text.dart';

/// Uma linha da lista de Planos (até 3 informações, Miller): nome, valor à
/// direita ("Dia 23 de 300", "4× por semana", "Pausado") e a linha de
/// baixo; a barra só nos ativos em andamento.
@immutable
class PlanListItem {
  const PlanListItem({
    required this.plan,
    required this.value,
    required this.line,
    this.progress,
    this.progressSemantics,
  });

  final Plan plan;
  final String value;
  final String line;

  /// 0–1; `null` esconde a barra.
  final double? progress;
  final String? progressSemantics;
}

/// A linha de um plano em [today].
PlanListItem planListItem(PlanSnapshot snapshot, {required LocalDate today}) {
  final plan = snapshot.plan;
  if (plan.status == PlanStatus.archived) {
    return PlanListItem(
      plan: plan,
      value: 'Arquivado',
      line: periodText(plan.startDate, plan.lastDay),
    );
  }
  if (plan.isFinished(today)) {
    final early = plan.status == PlanStatus.endedEarly;
    return PlanListItem(
      plan: plan,
      value: early ? 'Encerrado' : 'Concluído',
      line: early
          ? 'Encerrado em ${plan.lastDay.toDisplay()}'
          : 'Terminou em ${plan.lastDay.toDisplay()}',
    );
  }
  if (plan.status == PlanStatus.paused) {
    final since = plan.pauses.where((p) => p.end == null).lastOrNull?.start;
    return PlanListItem(
      plan: plan,
      value: 'Pausado',
      line:
          '${since == null ? 'Pausado' : pausedSinceText(since, today)} · '
          'dias pausados não contam',
    );
  }
  // Ainda não começou (qualquer frequência).
  if (today.isBefore(plan.startDate)) {
    return PlanListItem(
      plan: plan,
      value: 'Começa em ${plan.startDate.toDisplay()}',
      line: '${formatMinutes(plan.dailyGoalMinutes)} por dia',
    );
  }
  if (plan.frequency case TimesPerWeekFrequency(:final timesPerWeek)) {
    final week = planWeekResults(snapshot, today, today: today);
    final done = week.where((r) => r.status.isFulfilled).length;
    final shown = done > timesPerWeek ? timesPerWeek : done;
    return PlanListItem(
      plan: plan,
      value: '$timesPerWeek× por semana',
      line: '$shown de $timesPerWeek dias nesta semana',
      progress: shown / timesPerWeek,
      progressSemantics: '$shown de $timesPerWeek dias',
    );
  }
  final total = plan.startDate.daysUntil(plan.endDate) + 1;
  final dayNumber = plan.startDate.daysUntil(today) + 1;
  final result = planDayResult(snapshot, today, today: today);
  final done = formatMinutes(result.doneMinutes);
  final goal = formatMinutes(result.goalMinutes);
  return PlanListItem(
    plan: plan,
    value: 'Dia $dayNumber de $total',
    line: result.restDay && result.doneMinutes == 0
        ? 'Hoje é folga'
        : 'Hoje · $done de $goal',
    progress: result.goalMinutes == 0
        ? 0
        : (result.doneMinutes / result.goalMinutes).clamp(0, 1),
    progressSemantics: '$done de $goal',
  );
}
