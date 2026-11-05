import '../../../core/domain/local_date.dart';
import '../../../core/ui/content/nexo_task_item.dart';

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

const _weekdayShort = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
const _weekdayLong = [
  'segunda',
  'terça',
  'quarta',
  'quinta',
  'sexta',
  'sábado',
  'domingo',
];

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _ddmm(LocalDate d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// Texto do `Nexo/Deadline` (formato curto e relativo da lib) e o texto
/// completo para o leitor de tela.
///
/// [markToday] liga o tom "Hoje" (só em listas com datas misturadas, como o
/// bloco Hoje do Início).
NexoDeadline deadlineFor(
  DateTime due,
  DateTime now, {
  required bool completed,
  bool markToday = false,
}) {
  final today = LocalDate.fromDateTime(now);
  final day = LocalDate.fromDateTime(due);
  final time = _hhmm(due);
  final diff = today.daysUntil(day);
  final overdue = !completed && due.isBefore(now);

  if (overdue) {
    final (short, long) = switch (diff) {
      0 => ('hoje, $time', 'hoje às $time'),
      -1 => ('ontem, $time', 'ontem às $time'),
      _ => (_ddmm(day), 'em ${_ddmm(day)}'),
    };
    return NexoDeadline(
      text: 'Atrasada · $short',
      semanticsLabel: 'Atrasada. Prazo: $long',
      tone: NexoDeadlineTone.overdue,
    );
  }

  final (String short, String long) = switch (diff) {
    0 => ('Hoje · $time', 'hoje às $time'),
    1 => ('Amanhã · $time', 'amanhã às $time'),
    > 1 && < 7 => (
      '${_weekdayShort[day.weekday - 1]} · $time',
      '${_weekdayLong[day.weekday - 1]} às $time',
    ),
    _ => (_ddmm(day), 'em ${_ddmm(day)}'),
  };
  return NexoDeadline(
    text: short,
    semanticsLabel: 'Prazo: $long',
    tone: markToday && diff == 0
        ? NexoDeadlineTone.today
        : NexoDeadlineTone.normal,
  );
}
