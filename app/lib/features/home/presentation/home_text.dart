export '../../../core/format/duration_text.dart';
export '../../plans/presentation/plan_text.dart' show shortDayText, streakText;
export '../../tasks/presentation/task_text.dart' show completedFor, deadlineFor;

/// "1 tarefa", "5 tarefas".
String tasksCount(int n) => n == 1 ? '1 tarefa' : '$n tarefas';
