import '../../../core/domain/local_date.dart';
import 'task.dart';

/// Seções da visualização "Por prazo" (design de Tarefas, 04/11/2026), na
/// ordem da tela. Grupos vazios não aparecem.
enum TaskSection {
  overdue('Atrasadas'),
  today('Hoje'),
  tomorrow('Amanhã'),

  /// Depois de amanhã até o sábado (semana do Nexo: domingo a sábado).
  thisWeek('Esta semana'),
  later('Depois'),
  noDue('Sem prazo'),

  /// Concluídas nos últimos [completedWindowDays] dias (hoje incluso).
  completed('Concluídas');

  const TaskSection(this.label);

  final String label;
}

/// Abas da visualização "Hoje, Próximas e Concluídas".
enum TaskTab {
  /// Atrasadas no topo + as de hoje.
  today('Hoje'),

  /// De amanhã em diante + sem prazo.
  upcoming('Próximas'),
  completed('Concluídas');

  const TaskTab(this.label);

  final String label;
}

/// Quantos dias a seção Concluídas cobre (hoje e os 6 anteriores).
const completedWindowDays = 7;

/// Seção da tarefa em [now], ou `null` se concluída há mais de
/// [completedWindowDays] dias (sai da lista).
TaskSection? taskSectionOf(NexoTask task, DateTime now) {
  final today = LocalDate.fromDateTime(now);
  if (task.completed) {
    final at = task.completedAt;
    // Sem carimbo ainda (gravação pendente): acabou de ser concluída.
    if (at == null) return TaskSection.completed;
    final ago = LocalDate.fromDateTime(at).daysUntil(today);
    return ago < completedWindowDays ? TaskSection.completed : null;
  }
  final due = task.dueAt;
  if (due == null) return TaskSection.noDue;
  if (due.isBefore(now)) return TaskSection.overdue;
  final day = LocalDate.fromDateTime(due);
  final diff = today.daysUntil(day);
  if (diff == 0) return TaskSection.today;
  if (diff == 1) return TaskSection.tomorrow;
  if (day.compareTo(NexoWeek.endOf(today)) <= 0) return TaskSection.thisWeek;
  return TaskSection.later;
}

/// Ordem dentro da seção: concluídas da mais recente para a mais antiga;
/// sem prazo, prioridade alta primeiro; as demais pelo horário e, no mesmo
/// horário, prioridade alta primeiro. Empate: título.
int compareInSection(TaskSection section, NexoTask a, NexoTask b) {
  int byTitle() => a.title.toLowerCase().compareTo(b.title.toLowerCase());
  int byPriority() {
    final ah = a.priority == TaskPriority.high ? 0 : 1;
    final bh = b.priority == TaskPriority.high ? 0 : 1;
    return ah.compareTo(bh);
  }

  switch (section) {
    case TaskSection.completed:
      final at = a.completedAt;
      final bt = b.completedAt;
      if (at != bt) {
        if (at == null) return -1;
        if (bt == null) return 1;
        return bt.compareTo(at);
      }
      return byTitle();
    case TaskSection.noDue:
      final p = byPriority();
      return p != 0 ? p : byTitle();
    default:
      final d = a.dueAt!.compareTo(b.dueAt!);
      if (d != 0) return d;
      final p = byPriority();
      return p != 0 ? p : byTitle();
  }
}

/// Um grupo da lista: a seção e as tarefas já ordenadas.
typedef TaskGroup = ({TaskSection section, List<NexoTask> tasks});

/// Agrupa por prazo, na ordem de [TaskSection], sem grupos vazios.
List<TaskGroup> groupTasksByDue(Iterable<NexoTask> tasks, DateTime now) {
  final buckets = <TaskSection, List<NexoTask>>{};
  for (final task in tasks) {
    final section = taskSectionOf(task, now);
    if (section != null) (buckets[section] ??= []).add(task);
  }
  return [
    for (final section in TaskSection.values)
      if (buckets[section] case final list?)
        (
          section: section,
          tasks: list..sort((a, b) => compareInSection(section, a, b)),
        ),
  ];
}

/// As três abas, sempre presentes (podem vir vazias), na ordem de [TaskTab].
Map<TaskTab, List<NexoTask>> tasksByTab(
  Iterable<NexoTask> tasks,
  DateTime now,
) {
  final result = {for (final tab in TaskTab.values) tab: <NexoTask>[]};
  for (final group in groupTasksByDue(tasks, now)) {
    final tab = switch (group.section) {
      TaskSection.overdue || TaskSection.today => TaskTab.today,
      TaskSection.completed => TaskTab.completed,
      _ => TaskTab.upcoming,
    };
    result[tab]!.addAll(group.tasks);
  }
  return result;
}

/// Progresso de uma disciplina: entregas concluídas (não nota) e a próxima
/// pendente com prazo (a atrasada mais antiga, se houver).
typedef SubjectProgress = ({
  int done,
  int total,
  NexoTask? next,
  bool nextOverdue,
});

SubjectProgress subjectProgressOf(
  String subjectId,
  Iterable<NexoTask> tasks,
  DateTime now,
) {
  var done = 0;
  var total = 0;
  NexoTask? next;
  for (final task in tasks) {
    if (task.subjectId != subjectId) continue;
    total++;
    if (task.completed) {
      done++;
      continue;
    }
    final due = task.dueAt;
    if (due != null && (next == null || due.isBefore(next.dueAt!))) {
      next = task;
    }
  }
  return (
    done: done,
    total: total,
    next: next,
    nextOverdue: next != null && next.isOverdue(now),
  );
}
