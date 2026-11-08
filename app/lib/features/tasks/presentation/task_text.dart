import '../../../core/domain/local_date.dart';
import '../../../core/ui/content/nexo_task_item.dart';

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

/// "seg", "ter"... (minúsculo) para [day].
String weekdayShortLower(LocalDate day) =>
    _weekdayShort[day.weekday - 1].toLowerCase();

/// "dd/mm".
String ddmm(LocalDate day) => _ddmm(day);

/// Dia relativo, minúsculo, usado por todos os textos de data das tarefas:
/// "hoje", "amanhã", "ontem", o dia da semana até 6 dias para frente ou
/// para trás ("qui") ou a data ("20/11").
String relativeDayText(LocalDate day, LocalDate today) =>
    switch (today.daysUntil(day)) {
      0 => 'hoje',
      1 => 'amanhã',
      -1 => 'ontem',
      > -7 && < 7 => weekdayShortLower(day),
      _ => _ddmm(day),
    };

String _capitalized(String s) => s[0].toUpperCase() + s.substring(1);

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
  final word = relativeDayText(day, today);

  // Atrasada: "hoje" e "ontem" com a hora; antes disso, só a data.
  if (!completed && due.isBefore(now)) {
    final recent = diff >= -1;
    return NexoDeadline(
      text: 'Atrasada · ${recent ? '$word, $time' : _ddmm(day)}',
      semanticsLabel:
          'Atrasada. Prazo: ${recent ? '$word às $time' : 'em ${_ddmm(day)}'}',
      tone: NexoDeadlineTone.overdue,
    );
  }

  // Até 6 dias: "Hoje · 18:00", "Amanhã · 09:00", "Sex · 19:00"; depois,
  // só a data.
  final near = diff >= 0 && diff < 7;
  final spoken = diff > 1 && diff < 7 ? _weekdayLong[day.weekday - 1] : word;
  return NexoDeadline(
    text: near ? '${_capitalized(word)} · $time' : word,
    semanticsLabel: 'Prazo: ${near ? '$spoken às $time' : 'em $word'}',
    // Concluída perde o tom (spec do pacote B, §3).
    tone: markToday && diff == 0 && !completed
        ? NexoDeadlineTone.today
        : NexoDeadlineTone.normal,
  );
}

/// Na seção Concluídas: "Concluída hoje", "Concluída ontem", "Concluída seg"
/// (até 6 dias) ou "Concluída em 28/10".
NexoDeadline completedFor(DateTime completedAt, DateTime now) {
  final today = LocalDate.fromDateTime(now);
  final day = LocalDate.fromDateTime(completedAt);
  final word = relativeDayText(day, today);
  final when = day.daysUntil(today) >= 7 ? 'em $word' : word;
  return NexoDeadline(
    text: 'Concluída $when',
    semanticsLabel: 'Concluída $when',
  );
}

/// Linha da próxima entrega do `Nexo/AcademicProgress` (design de Tarefas
/// 11): "Próxima: Lista 3 · qui" ou, atrasada, "Próxima: Lista 3 ·
/// atrasada" (em Error; a palavra garante que a cor não é o único sinal).
String nextDeliveryText(String title, DateTime due, DateTime now) {
  final when = due.isBefore(now)
      ? 'atrasada'
      : relativeDayText(
          LocalDate.fromDateTime(due),
          LocalDate.fromDateTime(now),
        );
  return 'Próxima: $title · $when';
}

String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// Rótulo do aviso de entrega no `Chip/Input`: "1 semana", "2 dias",
/// "1 dia", "3 horas" ou "90 min".
String reminderLabel(int minutes) {
  if (minutes % 10080 == 0) {
    return _plural(minutes ~/ 10080, 'semana', 'semanas');
  }
  if (minutes % 1440 == 0) return _plural(minutes ~/ 1440, 'dia', 'dias');
  if (minutes % 60 == 0) return _plural(minutes ~/ 60, 'hora', 'horas');
  return '$minutes min';
}

/// Valor do campo Prazo: "Hoje, 07/11/2026" ou "Sex, 14/11/2026".
String dueDateFieldText(LocalDate day, LocalDate today) {
  final word = day == today ? 'Hoje' : _weekdayShort[day.weekday - 1];
  return '$word, ${_ddmm(day)}/${day.year}';
}

/// "HH:mm".
String hhmm(DateTime t) => _hhmm(t);

/// Resumo no topo do detalhe da tarefa e se ele é um alerta (atrasada, em
/// Error): "Prazo hoje, 18:00", "Atrasada · venceu ontem, 23:59",
/// "Concluída em qua, 05/11" ou "Sem prazo".
({String text, bool overdue}) taskSummaryText({
  required bool completed,
  required DateTime? completedAt,
  required DateTime? dueAt,
  required DateTime now,
}) {
  final today = LocalDate.fromDateTime(now);
  if (completed) {
    final day = LocalDate.fromDateTime(completedAt ?? now);
    return (
      text: 'Concluída em ${weekdayShortLower(day)}, ${_ddmm(day)}',
      overdue: false,
    );
  }
  if (dueAt == null) return (text: 'Sem prazo', overdue: false);
  final when =
      '${relativeDayText(LocalDate.fromDateTime(dueAt), today)}, ${_hhmm(dueAt)}';
  if (dueAt.isBefore(now)) {
    return (text: 'Atrasada · venceu $when', overdue: true);
  }
  return (text: 'Prazo $when', overdue: false);
}
