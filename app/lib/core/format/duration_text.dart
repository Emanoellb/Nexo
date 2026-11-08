/// Duração como no design: "20 min", "1h 30min", "1h 05min", "2h".
///
/// Comum a Início, Planos e Foco (estava em `home_text.dart`).
String formatMinutes(int minutes) {
  final m = minutes.abs();
  final h = m ~/ 60;
  final rest = m % 60;
  if (h == 0) return '$rest min';
  if (rest == 0) return '${h}h';
  return '${h}h ${rest.toString().padLeft(2, '0')}min';
}
