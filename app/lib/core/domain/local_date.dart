import 'package:flutter/foundation.dart';

/// Data de calendário sem hora nem fuso: o "dia" do usuário.
///
/// Dois formatos, decisão de 26/10/2026:
/// - **na tela, sempre `DD/MM/AAAA`** ([toDisplay] e [LocalDate.parseDisplay]);
/// - **no banco, `AAAA-MM-DD`** ([toIso] e [LocalDate.parse]), que o usuário
///   não vê. As regras publicadas exigem esse formato e comparam datas como
///   texto, o que só funciona nessa ordem (`firestore.rules`, `isDate`).
///
/// Dias da semana como no Dart: 1 = segunda … 7 = domingo.
@immutable
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  /// Dia local do instante [dateTime] (no fuso do aparelho).
  factory LocalDate.fromDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return LocalDate(local.year, local.month, local.day);
  }

  /// Lê o formato do banco, `AAAA-MM-DD`. Lança [FormatException] se o texto
  /// ou a data for inválida (ex.: 2026-02-30).
  factory LocalDate.parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) throw FormatException('Data inválida', value);
    return _checked(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      value,
    );
  }

  /// Lê o que o usuário digita, `DD/MM/AAAA` (ex.: data de nascimento).
  /// Lança [FormatException] se o texto ou a data for inválida.
  factory LocalDate.parseDisplay(String value) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value.trim());
    if (match == null) throw FormatException('Data inválida', value);
    return _checked(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
      value,
    );
  }

  static LocalDate _checked(int year, int month, int day, String source) {
    final date = LocalDate(year, month, day);
    final check = date._utc;
    if (check.year != year || check.month != month || check.day != day) {
      throw FormatException('Data inexistente', source);
    }
    return date;
  }

  final int year;
  final int month;
  final int day;

  /// Meia-noite UTC do dia: base para contas sem efeito de horário de verão.
  DateTime get _utc => DateTime.utc(year, month, day);

  /// 1 = segunda … 7 = domingo.
  int get weekday => _utc.weekday;

  LocalDate addDays(int days) {
    final d = _utc.add(Duration(days: days));
    return LocalDate(d.year, d.month, d.day);
  }

  /// Dias de [this] até [other] (positivo se [other] vem depois).
  int daysUntil(LocalDate other) => other._utc.difference(_utc).inDays;

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;

  /// Início do dia no fuso do aparelho.
  DateTime get startOfDay => DateTime(year, month, day);

  /// Formato da tela: `DD/MM/AAAA`.
  String toDisplay() =>
      '${day.toString().padLeft(2, '0')}/'
      '${month.toString().padLeft(2, '0')}/'
      '${year.toString().padLeft(4, '0')}';

  /// Formato do banco: `AAAA-MM-DD`. Não mostre ao usuário.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDate other) => _utc.compareTo(other._utc);

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}

/// Semana do Nexo: **domingo a sábado** (decisão de 22/10/2026).
abstract final class NexoWeek {
  /// Domingo da semana de [date].
  static LocalDate startOf(LocalDate date) => date.addDays(-(date.weekday % 7));

  /// Sábado da semana de [date].
  static LocalDate endOf(LocalDate date) => startOf(date).addDays(6);

  /// Os 7 dias da semana de [date], de domingo a sábado.
  static List<LocalDate> daysOf(LocalDate date) {
    final start = startOf(date);
    return [for (var i = 0; i < 7; i++) start.addDays(i)];
  }
}
