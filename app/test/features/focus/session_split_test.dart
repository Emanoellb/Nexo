import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/focus/domain/session_split.dart';

void main() {
  test('sessão no mesmo dia vira um segmento só', () {
    final segments = splitSessionByDay([
      ActiveInterval(DateTime(2026, 10, 26, 9), DateTime(2026, 10, 26, 10, 30)),
    ]);
    expect(segments, hasLength(1));
    expect(segments.single.day, const LocalDate(2026, 10, 26));
    expect(segments.single.durationSeconds, 90 * 60);
  });

  test('23h30 às 0h45: 30 min num dia e 45 min no seguinte (RF13)', () {
    final segments = splitSessionByDay([
      ActiveInterval(
        DateTime(2026, 10, 26, 23, 30),
        DateTime(2026, 10, 27, 0, 45),
      ),
    ]);
    expect(segments, hasLength(2));
    expect(segments[0].day, const LocalDate(2026, 10, 26));
    expect(segments[0].durationSeconds, 30 * 60);
    expect(segments[0].endAt, DateTime(2026, 10, 27));
    expect(segments[1].day, const LocalDate(2026, 10, 27));
    expect(segments[1].durationSeconds, 45 * 60);
    expect(segments[1].startAt, DateTime(2026, 10, 27));
  });

  test('pausas não contam: a duração é só do tempo ativo', () {
    final segments = splitSessionByDay([
      ActiveInterval(DateTime(2026, 10, 26, 9), DateTime(2026, 10, 26, 9, 25)),
      // pausa das 9h25 às 9h40
      ActiveInterval(DateTime(2026, 10, 26, 9, 40), DateTime(2026, 10, 26, 10)),
    ]);
    final day = segments.single;
    expect(day.durationSeconds, 45 * 60);
    expect(day.startAt, DateTime(2026, 10, 26, 9));
    expect(day.endAt, DateTime(2026, 10, 26, 10));
    // Regra do contrato: duração líquida ≤ fim − início.
    expect(
      day.durationSeconds,
      lessThanOrEqualTo(day.endAt.difference(day.startAt).inSeconds),
    );
  });

  test('pausa atravessando a meia-noite deixa cada dia com o seu tempo', () {
    final segments = splitSessionByDay([
      ActiveInterval(
        DateTime(2026, 10, 26, 23, 40),
        DateTime(2026, 10, 26, 23, 50),
      ),
      ActiveInterval(
        DateTime(2026, 10, 27, 0, 10),
        DateTime(2026, 10, 27, 0, 30),
      ),
    ]);
    expect(segments.map((s) => s.durationSeconds), [10 * 60, 20 * 60]);
    expect(segments.map((s) => s.day.toIso()), ['2026-10-26', '2026-10-27']);
  });

  test('intervalo sem duração é recusado', () {
    final t = DateTime(2026, 10, 26, 9);
    expect(() => ActiveInterval(t, t), throwsArgumentError);
  });
}
