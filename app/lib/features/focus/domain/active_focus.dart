import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'focus_session.dart';
import 'session_split.dart';

/// Uma pausa do foco em andamento: de [start] até [end] (`null` = pausado
/// agora).
@immutable
class FocusPause {
  const FocusPause(this.start, [this.end]);

  final DateTime start;
  final DateTime? end;
}

/// O foco em andamento (spec do Foco, 07/11/2026). O cronômetro roda no
/// aparelho: só o horário de início e as pausas ficam guardados, e a sessão
/// só vai ao Firestore ao encerrar (contrato §4). Sobrevive ao app fechar
/// (guardado no aparelho, por conta).
@immutable
class ActiveFocus {
  ActiveFocus({
    required this.planId,
    required this.startedAt,
    List<FocusPause> pauses = const [],
    List<String> topicIds = const [],
    this.dnd = false,
  }) : pauses = List.unmodifiable(pauses),
       topicIds = List.unmodifiable(topicIds) {
    if (topicIds.length > FocusSession.maxTopics ||
        topicIds.toSet().length != topicIds.length) {
      throw ArgumentError('Até 3 tópicos por sessão, sem repetir.');
    }
  }

  final String planId;
  final DateTime startedAt;
  final List<FocusPause> pauses;
  final List<String> topicIds;

  /// "Não perturbe" ligado por este foco (volta ao estado anterior ao
  /// encerrar).
  final bool dnd;

  /// Menos que isso não é salvo ("Sessão muito curta para salvar.").
  static const minimum = Duration(minutes: 1);

  bool get isPaused => pauses.isNotEmpty && pauses.last.end == null;

  /// Desde quando está pausado.
  DateTime? get pausedSince => isPaused ? pauses.last.start : null;

  /// Tempo pausado até [now].
  Duration pausedUntil(DateTime now) => pauses.fold(
    Duration.zero,
    (sum, p) => sum + (p.end ?? now).difference(p.start),
  );

  /// Tempo líquido (sem as pausas) até [now].
  Duration elapsed(DateTime now) {
    final total = now.difference(startedAt) - pausedUntil(now);
    return total.isNegative ? Duration.zero : total;
  }

  /// Os trechos em que o cronômetro rodou até [now] (para dividir à
  /// meia-noite).
  List<ActiveInterval> intervals(DateTime now) {
    final result = <ActiveInterval>[];
    var cursor = startedAt;
    for (final pause in pauses) {
      if (pause.start.isAfter(cursor)) {
        result.add(ActiveInterval(cursor, pause.start));
      }
      final end = pause.end;
      if (end == null) return result;
      cursor = end;
    }
    if (now.isAfter(cursor)) result.add(ActiveInterval(cursor, now));
    return result;
  }

  ActiveFocus copyWith({
    List<FocusPause>? pauses,
    List<String>? topicIds,
    bool? dnd,
  }) => ActiveFocus(
    planId: planId,
    startedAt: startedAt,
    pauses: pauses ?? this.pauses,
    topicIds: topicIds ?? this.topicIds,
    dnd: dnd ?? this.dnd,
  );

  ActiveFocus pause(DateTime now) =>
      isPaused ? this : copyWith(pauses: [...pauses, FocusPause(now)]);

  ActiveFocus resume(DateTime now) => isPaused
      ? copyWith(
          pauses: [
            ...pauses.sublist(0, pauses.length - 1),
            FocusPause(pauses.last.start, now),
          ],
        )
      : this;

  String toJson() => jsonEncode({
    'planId': planId,
    'startedAt': startedAt.toIso8601String(),
    'pauses': [
      for (final p in pauses)
        [p.start.toIso8601String(), p.end?.toIso8601String()],
    ],
    'topicIds': topicIds,
    'dnd': dnd,
  });

  /// `null` se o texto não for um foco válido (ex.: versão antiga).
  static ActiveFocus? fromJson(String? text) {
    if (text == null) return null;
    try {
      final map = jsonDecode(text) as Map<String, Object?>;
      return ActiveFocus(
        planId: map['planId']! as String,
        startedAt: DateTime.parse(map['startedAt']! as String),
        pauses: [
          for (final p in (map['pauses']! as List).cast<List<Object?>>())
            FocusPause(
              DateTime.parse(p[0]! as String),
              p[1] == null ? null : DateTime.parse(p[1]! as String),
            ),
        ],
        topicIds: (map['topicIds']! as List).cast<String>(),
        dnd: map['dnd'] as bool? ?? false,
      );
    } on Object {
      return null;
    }
  }
}
