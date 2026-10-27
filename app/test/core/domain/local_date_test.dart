import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/domain/edit_window.dart';
import 'package:nexo/core/domain/local_date.dart';

void main() {
  group('LocalDate', () {
    test('lê e grava AAAA-MM-DD', () {
      final date = LocalDate.parse('2026-10-26');
      expect(date, const LocalDate(2026, 10, 26));
      expect(date.toIso(), '2026-10-26');
      expect(const LocalDate(2026, 1, 5).toIso(), '2026-01-05');
    });

    test('recusa formato e data inexistente', () {
      expect(() => LocalDate.parse('26/10/2026'), throwsFormatException);
      expect(() => LocalDate.parse('2026-02-30'), throwsFormatException);
      expect(() => LocalDate.parse('2026-13-01'), throwsFormatException);
    });

    test('na tela: mostra e lê DD/MM/AAAA', () {
      const date = LocalDate(2026, 1, 5);
      expect(date.toDisplay(), '05/01/2026');
      expect(LocalDate.parseDisplay('05/01/2026'), date);
      expect(
        LocalDate.parseDisplay(' 26/10/2026 '),
        const LocalDate(2026, 10, 26),
      );
    });

    test('na tela: recusa outro formato e data inexistente', () {
      expect(() => LocalDate.parseDisplay('2026-01-05'), throwsFormatException);
      expect(() => LocalDate.parseDisplay('5/1/2026'), throwsFormatException);
      expect(() => LocalDate.parseDisplay('31/04/2026'), throwsFormatException);
    });

    test('tela e banco representam a mesma data', () {
      const date = LocalDate(2008, 2, 29);
      expect(
        LocalDate.parseDisplay(date.toDisplay()),
        LocalDate.parse(date.toIso()),
      );
    });

    test('ano bissexto', () {
      expect(LocalDate.parse('2028-02-29').toIso(), '2028-02-29');
      expect(() => LocalDate.parse('2026-02-29'), throwsFormatException);
    });

    test('soma dias atravessando mês e ano', () {
      expect(
        const LocalDate(2026, 12, 31).addDays(1),
        const LocalDate(2027, 1, 1),
      );
      expect(
        const LocalDate(2026, 3, 1).addDays(-1),
        const LocalDate(2026, 2, 28),
      );
    });

    test('dias até outra data e comparação', () {
      const a = LocalDate(2026, 10, 20);
      const b = LocalDate(2026, 10, 26);
      expect(a.daysUntil(b), 6);
      expect(b.daysUntil(a), -6);
      expect(a.isBefore(b), isTrue);
      expect(b.isAfter(a), isTrue);
    });

    test('dia da semana: 1 = segunda … 7 = domingo', () {
      expect(const LocalDate(2026, 10, 26).weekday, DateTime.monday);
      expect(const LocalDate(2026, 10, 25).weekday, DateTime.sunday);
    });

    test('dia local de um instante', () {
      expect(
        LocalDate.fromDateTime(DateTime(2026, 10, 26, 23, 59)),
        const LocalDate(2026, 10, 26),
      );
    });
  });

  group('NexoWeek (domingo a sábado)', () {
    test('segunda pertence à semana iniciada no domingo anterior', () {
      const monday = LocalDate(2026, 10, 26);
      expect(NexoWeek.startOf(monday), const LocalDate(2026, 10, 25));
      expect(NexoWeek.endOf(monday), const LocalDate(2026, 10, 31));
    });

    test('domingo começa a própria semana; sábado a termina', () {
      const sunday = LocalDate(2026, 10, 25);
      const saturday = LocalDate(2026, 10, 31);
      expect(NexoWeek.startOf(sunday), sunday);
      expect(NexoWeek.startOf(saturday), sunday);
    });

    test('os 7 dias em ordem, de D a S', () {
      final days = NexoWeek.daysOf(const LocalDate(2026, 10, 28));
      expect(days.first.weekday, DateTime.sunday);
      expect(days.last.weekday, DateTime.saturday);
      expect(days.length, 7);
    });
  });

  group('janela de 7 dias', () {
    const today = LocalDate(2026, 10, 26);

    test('hoje e até 7 dias atrás valem', () {
      expect(isWithinEditWindow(today, today: today), isTrue);
      expect(isWithinEditWindow(today.addDays(-7), today: today), isTrue);
    });

    test('8 dias atrás e o futuro ficam fora', () {
      expect(isWithinEditWindow(today.addDays(-8), today: today), isFalse);
      expect(isWithinEditWindow(today.addDays(1), today: today), isFalse);
    });
  });
}
