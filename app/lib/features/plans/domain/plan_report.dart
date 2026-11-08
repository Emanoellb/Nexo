import 'package:flutter/foundation.dart';

import '../../../core/domain/local_date.dart';
import '../../focus/domain/focus_session.dart';
import 'plan.dart';
import 'plan_day_result.dart';
import 'plan_schedule.dart';

/// Totais da Visão geral ("Até ontem") e do Relatório final (design de
/// Planos 2c, 07/11/2026). Tudo calculado pelo app a partir dos dias e das
/// versões (firestore-rules.md §4: "Totais ... calculados pelo app").
@immutable
class PlanReport {
  const PlanReport({
    required this.doneMinutes,
    required this.plannedMinutes,
    required this.metDays,
    required this.metShortDays,
    required this.metOverDays,
    required this.missedDays,
    required this.offDays,
    required this.activeDays,
    required this.currentStreak,
    required this.longestStreak,
    required this.points,
  });

  /// Minutos dedicados nos dias contados.
  final int doneMinutes;

  /// Soma das metas dos dias que contam (folga e pausa não entram).
  final int plannedMinutes;
  final int metDays;
  final int metShortDays;
  final int metOverDays;
  final int missedDays;

  /// "Folga ou pausa".
  final int offDays;

  /// Dias com algum minuto dedicado ("nos dias com atividade").
  final int activeDays;
  final int currentStreak;
  final int longestStreak;
  final int points;

  /// Saldo com a compensação: dedicado − planejado (negativo = faltou).
  int get balanceMinutes => doneMinutes - plannedMinutes;

  int get fulfilledDays => metDays + metShortDays + metOverDays;

  /// Dias que contam (cumpridos + não cumpridos).
  int get countedDays => fulfilledDays + missedDays;

  /// Média por dia com atividade, em minutos.
  int get averageMinutes => activeDays == 0 ? 0 : doneMinutes ~/ activeDays;
}

/// Último dia que o relatório cobre: ontem (plano em andamento) ou o fim
/// (encerrado antes, concluído ou arquivado depois de encerrar).
LocalDate reportLastDay(Plan plan, {required LocalDate today}) {
  final end = plan.endedOn ?? plan.endDate;
  final yesterday = today.addDays(-1);
  return end.isBefore(yesterday) ? end : yesterday;
}

/// Calcula o [PlanReport] do início até [lastDay] (inclusive).
PlanReport planReport(
  PlanSnapshot snapshot, {
  required LocalDate today,
  LocalDate? lastDay,
}) {
  final plan = snapshot.plan;
  final last = lastDay ?? reportLastDay(plan, today: today);
  var done = 0;
  var planned = 0;
  var met = 0;
  var short = 0;
  var over = 0;
  var missed = 0;
  var off = 0;
  var active = 0;
  var points = 0;
  var longest = 0;
  var running = 0;

  for (
    var week = NexoWeek.startOf(plan.startDate);
    !week.isAfter(last);
    week = week.addDays(7)
  ) {
    final results = planWeekResults(snapshot, week, today: today);
    for (final r in results) {
      if (r.day.isBefore(plan.startDate) || r.day.isAfter(last)) continue;
      if (r.doneMinutes > 0) active++;
      points += r.points;
      switch (r.status) {
        case PlanDayStatus.off:
          off++;
          continue;
        case PlanDayStatus.met:
          met++;
        case PlanDayStatus.metShort:
          short++;
        case PlanDayStatus.metOver:
          over++;
        case PlanDayStatus.missed:
          missed++;
        case PlanDayStatus.inProgress:
          // Não acontece antes de hoje; por segurança, não conta.
          continue;
      }
      done += r.doneMinutes;
      planned += r.goalMinutes;
      if (r.status.isFulfilled) {
        running++;
        if (running > longest) longest = running;
      } else if (!r.flexible) {
        running = 0;
      }
    }
    // "× por semana": a semana fechada abaixo da cota quebra a sequência.
    if (_weekBelowQuota(snapshot, results, last)) running = 0;
  }

  return PlanReport(
    doneMinutes: done,
    plannedMinutes: planned,
    metDays: met,
    metShortDays: short,
    metOverDays: over,
    missedDays: missed,
    offDays: off,
    activeDays: active,
    currentStreak: currentStreak(snapshot, today: today),
    longestStreak: longest,
    points: points,
  );
}

bool _weekBelowQuota(
  PlanSnapshot snapshot,
  List<PlanDayResult> week,
  LocalDate last,
) {
  if (week.last.day.isAfter(last)) return false;
  int? quota;
  var available = 0;
  for (final r in week) {
    final plan = snapshot.plan;
    if (!isWithinPlanPeriod(
          day: r.day,
          startDate: plan.startDate,
          endDate: plan.endDate,
          endedOn: plan.endedOn,
        ) ||
        isPausedOn(plan.pauses, r.day)) {
      continue;
    }
    final version = versionFor(snapshot.versions, r.day);
    if (version == null) continue;
    available++;
    if (version.frequency case TimesPerWeekFrequency(:final timesPerWeek)) {
      quota = timesPerWeek;
    }
  }
  if (quota == null) return false;
  final required = quota < available ? quota : available;
  return week.where((r) => r.status.isFulfilled).length < required;
}

/// Minutos por tópico: cada sessão divide a duração igualmente entre os
/// tópicos dela (v0.9). Tópico apagado não aparece (a sessão fica "sem
/// tópico").
Map<String, int> topicMinutes(Iterable<FocusSession> sessions) {
  final seconds = <String, double>{};
  for (final s in sessions) {
    if (s.topicIds.isEmpty) continue;
    final share = s.durationSeconds / s.topicIds.length;
    for (final id in s.topicIds) {
      seconds[id] = (seconds[id] ?? 0) + share;
    }
  }
  return {for (final e in seconds.entries) e.key: e.value ~/ 60};
}
