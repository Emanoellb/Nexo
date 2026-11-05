import 'package:flutter/foundation.dart';

import '../../../core/domain/local_date.dart';
import 'plan.dart';
import 'plan_schedule.dart';

/// Resultado de um dia do plano (lib, `Nexo/PlanDayStatus` e Conteúdo/05).
enum PlanDayStatus {
  /// Dia de estudo ainda aberto (hoje ou adiante) e abaixo da meta.
  inProgress,

  /// Cumprido na meta: realizado = meta.
  met,

  /// Cumprido com horas a menos: finalizado abaixo da meta (com algum
  /// estudo).
  metShort,

  /// Cumprido com horas a mais: realizado > meta.
  metOver,

  /// Não cumprido: o dia passou sem meta e sem finalizar.
  missed,

  /// Folga ou pausado: fora da frequência, do período, pausado, antes da
  /// primeira versão ou com a cota semanal já cumprida. Não entra na conta.
  off;

  /// Pontos do dia (lib, Conteúdo/06): 5 na meta, 3 com horas a menos,
  /// 7 com horas a mais (5 + 2), 0 não cumprido. Sem bônus de sequência.
  int get points => switch (this) {
    met => 5,
    metShort => 3,
    metOver => 7,
    inProgress || missed || off => 0,
  };

  bool get isFulfilled => this == met || this == metShort || this == metOver;
}

/// Um dia do plano já calculado. Meta, status e pontos não são gravados
/// (firestore-rules.md: "o app calcula").
@immutable
class PlanDayResult {
  const PlanDayResult({
    required this.day,
    required this.status,
    required this.goalMinutes,
    required this.doneMinutes,
    required this.finalized,
  });

  final LocalDate day;
  final PlanDayStatus status;

  /// Meta da versão vigente; 0 quando não há versão.
  final int goalMinutes;
  final int doneMinutes;
  final bool finalized;

  int get points => status.points;

  /// Realizado − meta (negativo = faltou).
  int get differenceMinutes => doneMinutes - goalMinutes;
}

/// O que o cálculo precisa do plano (lido dos repositórios).
@immutable
class PlanSnapshot {
  PlanSnapshot({
    required this.plan,
    required List<ScheduleVersion> versions,
    required Iterable<PlanDay> days,
  }) : versions = List.unmodifiable(versions),
       days = {for (final d in days) d.day: d};

  final Plan plan;
  final List<ScheduleVersion> versions;
  final Map<LocalDate, PlanDay> days;
}

/// Os 7 dias da semana (domingo a sábado) que contém [day].
///
/// "× por semana" é uma cota (decisão do usuário, 05/11/2026): todo dia é de
/// estudo até a pessoa cumprir X dias na semana; depois, os dias restantes
/// viram folga. Dia sem estudo nesse plano não vira "não cumprido" sozinho.
List<PlanDayResult> planWeekResults(
  PlanSnapshot snapshot,
  LocalDate day, {
  required LocalDate today,
}) {
  var fulfilled = 0;
  final results = <PlanDayResult>[];
  for (final d in NexoWeek.daysOf(day)) {
    final version = _activeVersion(snapshot, d);
    var result = _baseResult(snapshot, d, version, today);
    if (version != null && version.frequency is TimesPerWeekFrequency) {
      final quota = (version.frequency as TimesPerWeekFrequency).timesPerWeek;
      if (result.status != PlanDayStatus.off &&
          (fulfilled >= quota || result.status == PlanDayStatus.missed)) {
        result = _withStatus(result, PlanDayStatus.off);
      }
    }
    if (result.status.isFulfilled) fulfilled++;
    results.add(result);
  }
  return results;
}

/// O resultado de [day].
PlanDayResult planDayResult(
  PlanSnapshot snapshot,
  LocalDate day, {
  required LocalDate today,
}) => planWeekResults(
  snapshot,
  day,
  today: today,
).firstWhere((r) => r.day == day);

/// Pontos somados da semana de [day]. Para gravar em `users.points`, o app
/// compara a semana antes e depois de cada mudança (sessão, finalizar,
/// desfazer): na cota semanal, um dia pode mudar o status de outro.
int planWeekPoints(
  PlanSnapshot snapshot,
  LocalDate day, {
  required LocalDate today,
}) => planWeekResults(
  snapshot,
  day,
  today: today,
).fold(0, (sum, r) => sum + r.points);

/// Pontos de todos os dias do plano, do início até a semana de [today]
/// (ex.: para alinhar `users.points` aos dados de exemplo).
int planTotalPoints(PlanSnapshot snapshot, {required LocalDate today}) {
  var total = 0;
  for (
    var week = NexoWeek.startOf(snapshot.plan.startDate);
    !week.isAfter(today);
    week = week.addDays(7)
  ) {
    total += planWeekPoints(snapshot, week, today: today);
  }
  return total;
}

/// Sequência atual: dias cumpridos seguidos até [today].
///
/// - Folga não quebra (inclusive o resto da semana com a cota cumprida).
/// - "Não cumprido" quebra.
/// - Hoje ainda em andamento não conta nem quebra (o dia não acabou).
/// - "× por semana" (decisão do usuário, 05/11/2026): a semana que FECHOU
///   (domingo a sábado) abaixo da cota quebra a sequência; os dias sem
///   estudo continuam sendo folga.
int currentStreak(PlanSnapshot snapshot, {required LocalDate today}) {
  final start = snapshot.plan.startDate;
  var streak = 0;
  for (
    var week = NexoWeek.startOf(today);
    !NexoWeek.endOf(week).isBefore(start);
    week = week.addDays(-7)
  ) {
    final results = planWeekResults(snapshot, week, today: today);
    if (_closedBelowQuota(snapshot, results, today)) return streak;
    for (final r in results.reversed) {
      if (r.day.isAfter(today) || r.day.isBefore(start)) continue;
      if (r.status.isFulfilled) {
        streak++;
      } else if (r.status == PlanDayStatus.missed) {
        return streak;
      }
    }
  }
  return streak;
}

/// Semana já encerrada de um plano "× por semana" com menos dias cumpridos
/// que a cota. A cota é limitada aos dias em que o plano valia (início no
/// meio da semana, pausa).
bool _closedBelowQuota(
  PlanSnapshot snapshot,
  List<PlanDayResult> week,
  LocalDate today,
) {
  if (!week.last.day.isBefore(today)) return false;
  int? quota;
  var available = 0;
  for (final r in week) {
    final version = _activeVersion(snapshot, r.day);
    if (version == null) continue;
    available++;
    if (version.frequency case TimesPerWeekFrequency(:final timesPerWeek)) {
      quota = timesPerWeek;
    }
  }
  if (quota == null) return false;
  final required = quota < available ? quota : available;
  final fulfilled = week.where((r) => r.status.isFulfilled).length;
  return fulfilled < required;
}

/// Versão vigente, se o dia está no período e o plano não está pausado.
ScheduleVersion? _activeVersion(PlanSnapshot s, LocalDate day) {
  final plan = s.plan;
  if (!isWithinPlanPeriod(
        day: day,
        startDate: plan.startDate,
        endDate: plan.endDate,
        endedOn: plan.endedOn,
      ) ||
      isPausedOn(plan.pauses, day)) {
    return null;
  }
  return versionFor(s.versions, day);
}

PlanDayResult _baseResult(
  PlanSnapshot s,
  LocalDate day,
  ScheduleVersion? version,
  LocalDate today,
) {
  final record = s.days[day];
  final done = record?.doneMinutes ?? 0;
  final finalized = record?.isFinalized ?? false;
  final goal = version?.dailyGoalMinutes ?? 0;

  PlanDayStatus status;
  if (version == null || isScheduledWeekday(version.frequency, day) == false) {
    status = PlanDayStatus.off;
  } else if (done > goal) {
    status = PlanDayStatus.metOver;
  } else if (done == goal) {
    status = PlanDayStatus.met;
  } else if (finalized && done > 0) {
    status = PlanDayStatus.metShort;
  } else if (!day.isBefore(today)) {
    status = PlanDayStatus.inProgress;
  } else {
    status = PlanDayStatus.missed;
  }

  return PlanDayResult(
    day: day,
    status: status,
    goalMinutes: goal,
    doneMinutes: done,
    finalized: finalized,
  );
}

PlanDayResult _withStatus(PlanDayResult r, PlanDayStatus status) =>
    PlanDayResult(
      day: r.day,
      status: status,
      goalMinutes: r.goalMinutes,
      doneMinutes: r.doneMinutes,
      finalized: r.finalized,
    );
