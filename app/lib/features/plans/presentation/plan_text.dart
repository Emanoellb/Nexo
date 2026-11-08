import '../../../core/domain/local_date.dart';
import '../../../core/format/duration_text.dart';
import '../../tasks/presentation/task_text.dart';
import '../../subjects/domain/subject.dart';
import '../domain/plan.dart';
import '../domain/plan_schedule.dart';

const _weekdayNames = [
  'segunda',
  'terça',
  'quarta',
  'quinta',
  'sexta',
  'sábado',
  'domingo',
];

const _months = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

String _capitalized(String s) => s[0].toUpperCase() + s.substring(1);

/// "12 dias seguidos", "1 dia seguido" ou o convite para começar (cartão
/// do plano).
String streakText(int days) => switch (days) {
  0 => 'Comece sua sequência hoje',
  1 => '1 dia seguido',
  _ => '$days dias seguidos',
};

/// "seg, 10/11" (próximo dia com atividade no cartão do plano).
String shortDayText(LocalDate day) => '${weekdayShortLower(day)}, ${ddmm(day)}';

/// Linha de apoio do tópico: "Disciplina: Português" ou "Só deste plano".
String topicSupporting(String? subjectId, List<Subject> subjects) {
  final name = subjects.where((s) => s.id == subjectId).firstOrNull?.name;
  return name == null ? 'Só deste plano' : 'Disciplina: $name';
}

/// Iniciais dos dias no seletor, de domingo a sábado (semana do Nexo).
const weekdayInitials = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

/// Dias do seletor, de domingo a sábado, no número do Dart (7 = domingo).
const weekdayOrder = [7, 1, 2, 3, 4, 5, 6];

/// Nome completo do dia para o leitor de tela (1 = segunda … 7 = domingo).
String weekdayName(int weekday) => _weekdayNames[weekday - 1];

/// "Todos os dias", "Segunda a sexta", "Segunda, quarta e sexta" ou
/// "4× por semana".
String frequencyText(PlanFrequency frequency) => switch (frequency) {
  DailyFrequency() => 'Todos os dias',
  TimesPerWeekFrequency(:final timesPerWeek) => '$timesPerWeek× por semana',
  WeekdaysFrequency(:final weekdays) => _weekdaysText(weekdays),
};

String _weekdaysText(Set<int> weekdays) {
  final sorted = weekdays.toList()..sort();
  if (sorted.length == 7) return 'Todos os dias';
  final consecutive =
      sorted.length > 2 && sorted.last - sorted.first == sorted.length - 1;
  if (consecutive) {
    return _capitalized(
      '${weekdayName(sorted.first)} a ${weekdayName(sorted.last)}',
    );
  }
  final names = [for (final d in sorted) weekdayName(d)];
  final text = names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}';
  return _capitalized(text);
}

/// "15/10/2026 a 10/08/2027".
String periodText(LocalDate start, LocalDate end) =>
    '${start.toDisplay()} a ${end.toDisplay()}';

/// Rótulo da antecedência: "Na hora", "15 min antes", "30 min antes" ou
/// "1 h antes".
String reminderBeforeLabel(int minutes) => switch (minutes) {
  0 => 'Na hora',
  60 => '1 h antes',
  _ => '$minutes min antes',
};

/// "19:00 · aviso 15 min antes", "19:00 · aviso na hora" ou "19:00 · sem
/// aviso".
String studyTimeText(Plan plan) {
  final r = plan.reminderBefore;
  if (!r.enabled) return '${plan.studyTime} · sem aviso';
  final when = r.minutesBefore == 0
      ? 'na hora'
      : reminderBeforeLabel(r.minutesBefore);
  return '${plan.studyTime} · aviso $when';
}

/// "Até jul/2027" (lista de objetivos) ou "Sem prazo".
String goalDeadlineShort(LocalDate? deadline) => deadline == null
    ? 'Sem prazo'
    : 'Até ${_months[deadline.month - 1].substring(0, 3)}/${deadline.year}';

/// "Prazo: julho de 2027" (detalhe do objetivo); `null` sem prazo.
String? goalDeadlineLong(LocalDate? deadline) => deadline == null
    ? null
    : 'Prazo: ${_months[deadline.month - 1]} de ${deadline.year}';

/// "Novembro de 2026" (cabeçalho do calendário).
String monthTitle(int year, int month) =>
    '${_capitalized(_months[month - 1])} de $year';

/// "Qua, 5 de novembro" (dia tocado no calendário e cabeçalho das sessões).
String dayTitle(LocalDate day) =>
    '${_capitalized(weekdayShortLower(day))}, ${day.day} de ${_months[day.month - 1]}';

/// "Pausado desde 2/11" ou "Pausado desde hoje".
String pausedSinceText(LocalDate since, LocalDate today) => since == today
    ? 'Pausado desde hoje'
    : 'Pausado desde ${since.day}/${since.month}';

/// Saldo com sinal: "+1h 20min", "−1h 20min" ou "0 min".
String signedMinutes(int minutes) {
  if (minutes == 0) return '0 min';
  return '${minutes > 0 ? '+' : '−'}${formatMinutes(minutes)}';
}

/// "1 dia", "14 dias".
String daysCount(int n) => n == 1 ? '1 dia' : '$n dias';

/// Linha da meta no painel "Escolher plano principal": "Dia 40 de 180 · 45
/// min por dia" ou "4× por semana · 30 min por dia".
String planSummaryLine(Plan plan, LocalDate today) {
  final goal = '${formatMinutes(plan.dailyGoalMinutes)} por dia';
  if (plan.frequency case TimesPerWeekFrequency(:final timesPerWeek)) {
    return '$timesPerWeek× por semana · $goal';
  }
  final day = plan.startDate.daysUntil(today) + 1;
  final total = plan.startDate.daysUntil(plan.endDate) + 1;
  if (day < 1) return 'Começa em ${plan.startDate.toDisplay()} · $goal';
  return 'Dia ${day.clamp(1, total)} de $total · $goal';
}
