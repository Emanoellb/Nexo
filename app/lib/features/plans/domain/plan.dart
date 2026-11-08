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

/// "Avisar antes do horário" + "Antecedência" (`reminderBefore`, v0.9):
/// notificação local antes do Horário do plano. Na hora · 15 min · 30 min ·
/// 1 h antes. Padrão: ligado, 15 min.
@immutable
class PlanReminderBefore {
  PlanReminderBefore({required this.enabled, required this.minutesBefore}) {
    if (!options.contains(minutesBefore)) {
      throw ArgumentError.value(
        minutesBefore,
        'reminderBefore.minutesBefore',
        'use 0, 15, 30 ou 60',
      );
    }
  }

  /// Valores aceitos pelas regras.
  static const options = [0, 15, 30, 60];

  static final standard = PlanReminderBefore(enabled: true, minutesBefore: 15);

  final bool enabled;
  final int minutesBefore;

  Map<String, Object?> toMap() => {
    'enabled': enabled,
    'minutesBefore': minutesBefore,
  };

  factory PlanReminderBefore.fromMap(Map<String, Object?> map) =>
      PlanReminderBefore(
        enabled: map['enabled']! as bool,
        minutesBefore: map['minutesBefore']! as int,
      );

  @override
  bool operator ==(Object other) =>
      other is PlanReminderBefore &&
      other.enabled == enabled &&
      other.minutesBefore == minutesBefore;

  @override
  int get hashCode => Object.hash(enabled, minutesBefore);
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
    String studyTime = defaultStudyTime,
    PlanReminderBefore? reminderBefore,
  }) : name = checkText(name, 'name', 1, 80),
       studyTime = checkTime(studyTime, 'studyTime'),
       reminderBefore = reminderBefore ?? PlanReminderBefore.standard,
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

  /// Horário do plano sem o campo gravado (v0.9).
  static const defaultStudyTime = '19:00';

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

  /// Horário do plano, `HH:mm` (padrão 19:00).
  final String studyTime;
  final PlanReminderBefore reminderBefore;

  /// Encerrado em [today]: concluído, encerrado antes (com `endedOn`) ou
  /// com o fim do período já passado. Regra única para a lista, o detalhe,
  /// o menu e o Início. Arquivado conta só se tiver encerrado antes.
  bool isFinished(LocalDate today) =>
      status == PlanStatus.completed ||
      status == PlanStatus.endedEarly ||
      endedOn != null ||
      endDate.isBefore(today);

  /// Último dia do plano: `endedOn` (encerrado antes) ou o fim previsto.
  LocalDate get lastDay => endedOn ?? endDate;

  /// Cópia com campos trocados. `goalId` e `endedOn` vêm como funções para
  /// poder limpar (`() => null`).
  Plan copyWith({
    String? name,
    LocalDate? startDate,
    LocalDate? endDate,
    PlanFrequency? frequency,
    int? dailyGoalMinutes,
    PlanStatus? status,
    List<PlanPause>? pauses,
    LocalDate? Function()? endedOn,
    String? Function()? goalId,
    String? studyTime,
    PlanReminderBefore? reminderBefore,
  }) {
    return Plan(
      id: id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      frequency: frequency ?? this.frequency,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      status: status ?? this.status,
      pauses: pauses ?? this.pauses,
      endedOn: endedOn == null ? this.endedOn : endedOn(),
      goalId: goalId == null ? this.goalId : goalId(),
      studyTime: studyTime ?? this.studyTime,
      reminderBefore: reminderBefore ?? this.reminderBefore,
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
    'studyTime': studyTime,
    'reminderBefore': reminderBefore.toMap(),
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
      // Sem os campos (planos antigos), os padrões da v0.9.
      studyTime: map['studyTime'] as String? ?? defaultStudyTime,
      reminderBefore: map['reminderBefore'] == null
          ? null
          : PlanReminderBefore.fromMap(
              (map['reminderBefore']! as Map).cast<String, Object?>(),
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

  /// Campos do documento. `finalizedAt` vai SEMPRE, `null` quando não
  /// finalizado: o "Desfazer" (RF17) grava `finalizedAt: null`, nunca
  /// `FieldValue.delete()`, porque as regras v0.8 (`validDay`) exigem o
  /// campo (sessão das regras, 05/11/2026). O Firestore grava a hora do
  /// servidor no lugar de [finalizedAt].
  Map<String, Object?> toMap() => {
    'doneMinutes': doneMinutes,
    'finalizedAt': finalizedAt,
  };

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
