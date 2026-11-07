import '../../../core/domain/local_date.dart';
import '../../tasks/presentation/task_text.dart';

export '../../tasks/presentation/task_text.dart' show completedFor, deadlineFor;

/// Duração como no design: "20 min", "1h 30min", "1h 05min", "2h".
String formatMinutes(int minutes) {
  final m = minutes.abs();
  final h = m ~/ 60;
  final rest = m % 60;
  if (h == 0) return '$rest min';
  if (rest == 0) return '${h}h';
  return '${h}h ${rest.toString().padLeft(2, '0')}min';
}

/// "12 dias seguidos", "1 dia seguido" ou o convite para começar.
String streakText(int days) => switch (days) {
  0 => 'Comece sua sequência hoje',
  1 => '1 dia seguido',
  _ => '$days dias seguidos',
};

/// "1 tarefa", "5 tarefas".
String tasksCount(int n) => n == 1 ? '1 tarefa' : '$n tarefas';

/// "seg, 10/11" (próximo dia de estudo no cartão do plano).
String shortDayText(LocalDate day) => '${weekdayShortLower(day)}, ${ddmm(day)}';
