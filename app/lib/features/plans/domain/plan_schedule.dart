import 'package:flutter/foundation.dart';

import '../../../core/domain/local_date.dart';

/// Frequência do plano (RF02), como no contrato de `firestore-rules.md` §4.
@immutable
sealed class PlanFrequency {
  const PlanFrequency();

  /// Lê o mapa do Firestore (`{type: ...}`).
  factory PlanFrequency.fromMap(Map<String, Object?> map) {
    return switch (map['type']) {
      'daily' => const DailyFrequency(),
      'weekdays' => WeekdaysFrequency(
        (map['weekdays']! as List).cast<int>().toSet(),
      ),
      'timesPerWeek' => TimesPerWeekFrequency(map['timesPerWeek']! as int),
      final other => throw FormatException('Frequência desconhecida: $other'),
    };
  }

  Map<String, Object?> toMap();
}

/// "Todos os dias".
final class DailyFrequency extends PlanFrequency {
  const DailyFrequency();

  @override
  Map<String, Object?> toMap() => {'type': 'daily'};

  @override
  bool operator ==(Object other) => other is DailyFrequency;

  @override
  int get hashCode => 0;
}

/// "Dias da semana": 1 = segunda … 7 = domingo.
final class WeekdaysFrequency extends PlanFrequency {
  WeekdaysFrequency(Set<int> weekdays) : weekdays = Set.unmodifiable(weekdays) {
    if (weekdays.isEmpty || weekdays.any((d) => d < 1 || d > 7)) {
      throw ArgumentError.value(weekdays, 'weekdays', 'use 1 a 7');
    }
  }

  final Set<int> weekdays;

  @override
  Map<String, Object?> toMap() => {
    'type': 'weekdays',
    'weekdays': weekdays.toList()..sort(),
  };

  @override
  bool operator ==(Object other) =>
      other is WeekdaysFrequency && setEquals(other.weekdays, weekdays);

  @override
  int get hashCode => Object.hashAllUnordered(weekdays);
}

/// "× por semana" (semana de domingo a sábado), como cota (decisão do
/// usuário, 05/11/2026; firestore-rules.md §4, §5 e §7):
/// - todo dia é dia de estudo até a pessoa cumprir [timesPerWeek] dias na
///   semana; depois, os dias restantes viram folga;
/// - dia sem estudo é folga, nunca "não cumprido" sozinho;
/// - a sequência quebra quando a semana fecha abaixo da cota.
///
/// O cálculo fica em `plan_day_result.dart` (`planWeekResults`,
/// `currentStreak`).
final class TimesPerWeekFrequency extends PlanFrequency {
  TimesPerWeekFrequency(this.timesPerWeek) {
    if (timesPerWeek < 1 || timesPerWeek > 7) {
      throw ArgumentError.value(timesPerWeek, 'timesPerWeek', 'use 1 a 7');
    }
  }

  final int timesPerWeek;

  @override
  Map<String, Object?> toMap() => {
    'type': 'timesPerWeek',
    'timesPerWeek': timesPerWeek,
  };

  @override
  bool operator ==(Object other) =>
      other is TimesPerWeekFrequency && other.timesPerWeek == timesPerWeek;

  @override
  int get hashCode => timesPerWeek;
}

/// Uma versão da configuração (`scheduleVersions`): vale a partir de
/// [effectiveFrom] (RF04, "mudanças valem a partir do dia seguinte").
@immutable
class ScheduleVersion {
  const ScheduleVersion({
    required this.effectiveFrom,
    required this.frequency,
    required this.dailyGoalMinutes,
  });

  final LocalDate effectiveFrom;
  final PlanFrequency frequency;

  /// Meta diária em minutos (1–1440; a tela usa passos de 15).
  final int dailyGoalMinutes;
}

/// Versão vigente em [day]: a de `effectiveFrom` mais recente ≤ [day].
/// `null` antes da primeira versão. No empate (duas edições valendo no
/// mesmo dia, ex.: plano que ainda não começou), vale a criada por último:
/// [versions] vem na ordem de criação.
ScheduleVersion? versionFor(Iterable<ScheduleVersion> versions, LocalDate day) {
  ScheduleVersion? best;
  for (final version in versions) {
    if (version.effectiveFrom.isAfter(day)) continue;
    if (best == null || !version.effectiveFrom.isBefore(best.effectiveFrom)) {
      best = version;
    }
  }
  return best;
}

/// Data em que uma nova meta ou frequência passa a valer: amanhã, ou o
/// início do plano se ele ainda não começou (RF04).
LocalDate nextEffectiveFrom({
  required LocalDate today,
  required LocalDate planStart,
}) {
  final tomorrow = today.addDays(1);
  return planStart.isAfter(tomorrow) ? planStart : tomorrow;
}

/// Uma pausa do plano (RF05). [end] `null` = ainda pausado.
///
/// Vale a partir do dia em que começa; retomar também vale a partir do dia
/// em que retoma. Ou seja: dias pausados = de [start] (inclusive) até [end]
/// (exclusive).
@immutable
class PlanPause {
  const PlanPause({required this.start, this.end});

  final LocalDate start;
  final LocalDate? end;

  bool covers(LocalDate day) =>
      !day.isBefore(start) && (end == null || day.isBefore(end!));
}

bool isPausedOn(Iterable<PlanPause> pauses, LocalDate day) =>
    pauses.any((pause) => pause.covers(day));

/// O dia está dentro do período do plano (início a fim, ou até `endedOn`
/// quando o plano foi encerrado antes).
bool isWithinPlanPeriod({
  required LocalDate day,
  required LocalDate startDate,
  required LocalDate endDate,
  LocalDate? endedOn,
}) {
  final last = endedOn ?? endDate;
  return !day.isBefore(startDate) && !day.isAfter(last);
}

/// O dia está na frequência de "todos os dias" ou "dias da semana".
/// Para "× por semana" devolve `null`: o dia não se decide sozinho, depende
/// da cota da semana ([TimesPerWeekFrequency]; cálculo em
/// `planWeekResults`).
bool? isScheduledWeekday(PlanFrequency frequency, LocalDate day) {
  return switch (frequency) {
    DailyFrequency() => true,
    WeekdaysFrequency(:final weekdays) => weekdays.contains(day.weekday),
    TimesPerWeekFrequency() => null,
  };
}
