import 'package:flutter/foundation.dart';

import '../../../core/domain/field_rules.dart';
import '../../../core/domain/local_date.dart';

/// Origem da sessão: cronômetro (`focus`) ou "Registrar horas" (`manual`).
enum SessionSource {
  focus,
  manual;

  String get value => name;

  static SessionSource fromValue(String value) =>
      SessionSource.values.firstWhere((s) => s.value == value);
}

/// `…/plans/{planId}/sessions/{sessionId}` (contrato §4). Já dividida por
/// dia: uma sessão nunca atravessa a meia-noite (RF13).
@immutable
class FocusSession {
  FocusSession({
    required this.id,
    required this.planId,
    required this.startAt,
    required this.endAt,
    required this.durationSeconds,
    required this.source,
    required this.day,
    this.topicId,
    this.note,
  }) {
    if (!endAt.isAfter(startAt)) {
      throw ArgumentError('O fim da sessão precisa ser depois do início.');
    }
    if (endAt.difference(startAt) > const Duration(hours: 24)) {
      throw ArgumentError('Uma sessão vai até 24 horas.');
    }
    if (durationSeconds <= 0 ||
        durationSeconds > endAt.difference(startAt).inSeconds) {
      throw ArgumentError(
        'A duração líquida precisa ser maior que zero e caber entre início e fim.',
      );
    }
    checkTextOrNull(topicId, 'topicId', 1, 128);
    checkTextOrNull(note, 'note', 1, 500);
  }

  final String id;
  final String planId;
  final DateTime startAt;
  final DateTime endAt;

  /// Duração líquida, já sem as pausas.
  final int durationSeconds;
  final SessionSource source;
  final LocalDate day;

  /// Tópico do próprio plano; `null` = "sem tópico".
  final String? topicId;
  final String? note;

  /// Minutos inteiros que a sessão soma ao dia.
  int get minutes => durationSeconds ~/ 60;

  Map<String, Object?> toMap() => {
    'startAt': startAt,
    'endAt': endAt,
    'durationSeconds': durationSeconds,
    'source': source.value,
    'day': day.toIso(),
    'topicId': topicId,
    'note': note,
  };
}
