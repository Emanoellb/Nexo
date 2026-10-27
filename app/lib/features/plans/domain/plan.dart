import 'package:flutter/foundation.dart';

import '../../../core/domain/field_rules.dart';
import '../../../core/domain/local_date.dart';
import 'plan_schedule.dart';

/// Situação do plano (RF05, RF06), com o valor gravado no Firestore.
enum PlanStatus {
  active,
  paused,
  completed,
  endedEarly,
  archived,

  /// Só durante "Excluir plano" (o app apaga as subcoleções em lotes).
  deleting;

  String get value => name;

  static PlanStatus fromValue(String value) =>
      PlanStatus.values.firstWhere((s) => s.value == value);
}

/// Lembrete diário do plano (notificação local), ex.: 19:00.
@immutable
class PlanReminder {
  PlanReminder({required this.enabled, required String time})
    : time = checkTime(time, 'reminder.time');

  final bool enabled;

  /// `HH:mm`.
  final String time;

  Map<String, Object?> toMap() => {'enabled': enabled, 'time': time};

  factory PlanReminder.fromMap(Map<String, Object?> map) => PlanReminder(
    enabled: map['enabled']! as bool,
    time: map['time']! as String,
  );

  @override
  bool operator ==(Object other) =>
      other is PlanReminder && other.enabled == enabled && other.time == time;

  @override
  int get hashCode => Object.hash(enabled, time);
}

/// `users/{uid}/plans/{planId}` (contrato de `firestore-rules.md` §4).
///
/// `frequency` e `dailyGoalMinutes` são a cópia da versão mais recente; o
/// histórico fica em `scheduleVersions`. `createdAt`/`updatedAt` são
/// carimbos do servidor, gravados pelo repositório.
@immutable
class Plan {
  Plan({
    required this.id,
    required String name,
    required this.startDate,
    required this.endDate,
    required this.frequency,
    required int dailyGoalMinutes,
    this.status = PlanStatus.active,
    List<PlanPause> pauses = const [],
    this.endedOn,
    this.goalId,
    this.reminder,
  }) : name = checkText(name, 'name', 1, 80),
       dailyGoalMinutes = checkIntBetween(
         dailyGoalMinutes,
         'dailyGoalMinutes',
         1,
         1440,
       ),
       pauses = List.unmodifiable(pauses) {
    if (endDate.isBefore(startDate)) {
      throw ArgumentError('O fim do plano não pode vir antes do início.');
    }
    if (startDate.daysUntil(endDate) > maxPeriodDays) {
      throw ArgumentError('O período do plano vai até $maxPeriodDays dias.');
    }
    if (pauses.length > 100) {
      throw ArgumentError('O plano guarda até 100 pausas.');
    }
    if (status == PlanStatus.endedEarly && endedOn == null) {
      throw ArgumentError('Plano encerrado antes precisa de endedOn.');
    }
    if (endedOn != null &&
        (endedOn!.isBefore(startDate) || endedOn!.isAfter(endDate))) {
      throw ArgumentError('endedOn precisa estar dentro do período.');
    }
    checkTextOrNull(goalId, 'goalId', 1, 128);
  }

  /// Limite das regras: fim até 731 dias depois do início.
  static const maxPeriodDays = 731;

  final String id;
  final String name;
  final LocalDate startDate;
  final LocalDate endDate;
  final PlanFrequency frequency;
  final int dailyGoalMinutes;
  final PlanStatus status;
  final List<PlanPause> pauses;
  final LocalDate? endedOn;
  final String? goalId;
  final PlanReminder? reminder;

  Plan copyWith({
    String? name,
    LocalDate? endDate,
    PlanFrequency? frequency,
    int? dailyGoalMinutes,
    PlanStatus? status,
    List<PlanPause>? pauses,
    LocalDate? endedOn,
    String? goalId,
    PlanReminder? reminder,
  }) {
    return Plan(
      id: id,
      name: name ?? this.name,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      frequency: frequency ?? this.frequency,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      status: status ?? this.status,
      pauses: pauses ?? this.pauses,
      endedOn: endedOn ?? this.endedOn,
      goalId: goalId ?? this.goalId,
      reminder: reminder ?? this.reminder,
    );
  }

  /// Campos de dados do contrato (sem id e sem carimbos do servidor).
  Map<String, Object?> toMap() => {
    'name': name,
    'startDate': startDate.toIso(),
    'endDate': endDate.toIso(),
    'frequency': frequency.toMap(),
    'dailyGoalMinutes': dailyGoalMinutes,
    'status': status.value,
    'pauses': [
      for (final p in pauses) {'start': p.start.toIso(), 'end': p.end?.toIso()},
    ],
    'endedOn': endedOn?.toIso(),
    'goalId': goalId,
    'reminder': reminder?.toMap(),
  };

  factory Plan.fromMap(String id, Map<String, Object?> map) {
    LocalDate? date(Object? v) =>
        v == null ? null : LocalDate.parse(v as String);
    return Plan(
      id: id,
      name: map['name']! as String,
      startDate: LocalDate.parse(map['startDate']! as String),
      endDate: LocalDate.parse(map['endDate']! as String),
      frequency: PlanFrequency.fromMap(
        (map['frequency']! as Map).cast<String, Object?>(),
      ),
      dailyGoalMinutes: map['dailyGoalMinutes']! as int,
      status: PlanStatus.fromValue(map['status']! as String),
      pauses: [
        for (final p in (map['pauses'] as List?) ?? const [])
          PlanPause(
            start: LocalDate.parse((p as Map)['start']! as String),
            end: date(p['end']),
          ),
      ],
      endedOn: date(map['endedOn']),
      goalId: map['goalId'] as String?,
      reminder: map['reminder'] == null
          ? null
          : PlanReminder.fromMap(
              (map['reminder']! as Map).cast<String, Object?>(),
            ),
    );
  }
}

/// `…/plans/{planId}/topics/{topicId}`: tópico do plano, ligado ou não a
/// uma matéria (disciplina).
@immutable
class PlanTopic {
  PlanTopic({required this.id, required String name, this.subjectId})
    : name = checkText(name, 'name', 1, 80) {
    checkTextOrNull(subjectId, 'subjectId', 1, 128);
  }

  final String id;
  final String name;
  final String? subjectId;

  Map<String, Object?> toMap() => {'name': name, 'subjectId': subjectId};

  factory PlanTopic.fromMap(String id, Map<String, Object?> map) => PlanTopic(
    id: id,
    name: map['name']! as String,
    subjectId: map['subjectId'] as String?,
  );
}

/// `…/plans/{planId}/days/{AAAA-MM-DD}`. Só existe para dias com sessão ou
/// finalização. Meta, status e pontos do dia são calculados, não gravados.
@immutable
class PlanDay {
  PlanDay({required this.day, required int doneMinutes, this.finalizedAt})
    : doneMinutes = checkIntBetween(doneMinutes, 'doneMinutes', 0, 1440);

  /// Também é o id do documento.
  final LocalDate day;

  /// Soma das sessões do dia, em minutos.
  final int doneMinutes;

  /// Quando o dia foi finalizado; `null` se não foi (ou no "Desfazer").
  final DateTime? finalizedAt;

  bool get isFinalized => finalizedAt != null;

  PlanDay copyWith({
    int? doneMinutes,
    DateTime? finalizedAt,
    bool clearFinalized = false,
  }) => PlanDay(
    day: day,
    doneMinutes: doneMinutes ?? this.doneMinutes,
    finalizedAt: clearFinalized ? null : (finalizedAt ?? this.finalizedAt),
  );
}
