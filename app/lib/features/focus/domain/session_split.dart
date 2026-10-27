import 'package:flutter/foundation.dart';

import '../../../core/domain/local_date.dart';

/// Um trecho em que o cronômetro esteve rodando (entre "iniciar/retomar" e
/// "pausar/encerrar"). As pausas ficam de fora: só o tempo ativo conta.
@immutable
class ActiveInterval {
  ActiveInterval(this.start, this.end) {
    if (!end.isAfter(start)) {
      throw ArgumentError('O fim precisa ser depois do início.');
    }
  }

  final DateTime start;
  final DateTime end;
}

/// A parte de uma sessão que cai num dia: vira um documento de `sessions`
/// (`startAt`, `endAt`, `durationSeconds` líquido, `day`).
@immutable
class DaySegment {
  const DaySegment({
    required this.day,
    required this.startAt,
    required this.endAt,
    required this.durationSeconds,
  });

  final LocalDate day;
  final DateTime startAt;
  final DateTime endAt;

  /// Tempo ativo no dia, já sem as pausas (≤ `endAt − startAt`).
  final int durationSeconds;

  @override
  String toString() =>
      'DaySegment($day, $startAt → $endAt, ${durationSeconds}s)';
}

/// Divide a sessão à meia-noite (RF13), no fuso do aparelho: cada dia tem a
/// sua meta, status e pontos. Ex.: das 23h30 às 0h45 viram 30 min no
/// primeiro dia e 45 min no seguinte.
///
/// Os segmentos voltam em ordem de dia. Dias sem tempo ativo não aparecem.
List<DaySegment> splitSessionByDay(Iterable<ActiveInterval> intervals) {
  final byDay = <LocalDate, ({DateTime start, DateTime end, int seconds})>{};

  for (final interval in intervals) {
    var cursor = interval.start.toLocal();
    final end = interval.end.toLocal();
    while (cursor.isBefore(end)) {
      final day = LocalDate.fromDateTime(cursor);
      final nextMidnight = day.addDays(1).startOfDay;
      final pieceEnd = end.isBefore(nextMidnight) ? end : nextMidnight;
      final seconds = pieceEnd.difference(cursor).inSeconds;
      final current = byDay[day];
      byDay[day] = (
        start: current == null || cursor.isBefore(current.start)
            ? cursor
            : current.start,
        end: current == null || pieceEnd.isAfter(current.end)
            ? pieceEnd
            : current.end,
        seconds: (current?.seconds ?? 0) + seconds,
      );
      cursor = pieceEnd;
    }
  }

  final days = byDay.keys.toList()..sort();
  return [
    for (final day in days)
      if (byDay[day]!.seconds > 0)
        DaySegment(
          day: day,
          startAt: byDay[day]!.start,
          endAt: byDay[day]!.end,
          durationSeconds: byDay[day]!.seconds,
        ),
  ];
}
