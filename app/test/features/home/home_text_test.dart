import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/ui/ui.dart';
import 'package:nexo/features/home/application/home_view.dart';
import 'package:nexo/features/home/presentation/home_text.dart';
import 'package:nexo/features/tasks/domain/task.dart';

// Quarta, 04/11/2026, 10:00.
final _now = DateTime(2026, 11, 4, 10);

void main() {
  test('durações como no design', () {
    expect(formatMinutes(0), '0 min');
    expect(formatMinutes(20), '20 min');
    expect(formatMinutes(65), '1h 05min');
    expect(formatMinutes(90), '1h 30min');
    expect(formatMinutes(120), '2h');
    expect(formatMinutes(-20), '20 min');
  });

  test('sequência e contagem', () {
    expect(streakText(0), 'Comece sua sequência hoje');
    expect(streakText(1), '1 dia seguido');
    expect(streakText(12), '12 dias seguidos');
    expect(tasksCount(1), '1 tarefa');
    expect(tasksCount(5), '5 tarefas');
  });

  group('prazo (Nexo/Deadline)', () {
    NexoDeadline at(
      DateTime due, {
      bool completed = false,
      bool mark = false,
    }) => deadlineFor(due, _now, completed: completed, markToday: mark);

    test('hoje, amanhã, dia da semana e data', () {
      expect(at(DateTime(2026, 11, 4, 18)).text, 'Hoje · 18:00');
      expect(at(DateTime(2026, 11, 5, 9)).text, 'Amanhã · 09:00');
      expect(at(DateTime(2026, 11, 6, 23, 59)).text, 'Sex · 23:59');
      expect(
        at(DateTime(2026, 11, 6, 23, 59)).semanticsLabel,
        'Prazo: sexta às 23:59',
      );
      expect(at(DateTime(2026, 11, 20, 8)).text, '20/11');
    });

    test('atrasada: a palavra, o tom de erro e o texto completo', () {
      final d = at(DateTime(2026, 11, 3, 23, 59));
      expect(d.text, 'Atrasada · ontem, 23:59');
      expect(d.tone, NexoDeadlineTone.overdue);
      expect(d.semanticsLabel, 'Atrasada. Prazo: ontem às 23:59');
      expect(at(DateTime(2026, 11, 4, 8)).text, 'Atrasada · hoje, 08:00');
      expect(at(DateTime(2026, 10, 30, 8)).text, 'Atrasada · 30/10');
    });

    test('concluída nunca é atrasada; tom "Hoje" só quando pedido', () {
      expect(
        at(DateTime(2026, 11, 3, 23, 59), completed: true).tone,
        NexoDeadlineTone.normal,
      );
      expect(
        at(DateTime(2026, 11, 4, 18), mark: true).tone,
        NexoDeadlineTone.today,
      );
      expect(at(DateTime(2026, 11, 4, 18)).tone, NexoDeadlineTone.normal);
    });
  });

  test('grupos: Hoje (atrasadas + de hoje) e Próximas (7 dias)', () {
    NexoTask task(String title, DateTime? due, {bool done = false}) => NexoTask(
      id: title,
      title: title,
      dueAt: due,
    ).withCompleted(done, now: _now);
    final groups = groupTasks([
      task('atrasada', DateTime(2026, 11, 2, 8)),
      task('hoje', DateTime(2026, 11, 4, 18)),
      task('hoje feita', DateTime(2026, 11, 4, 8), done: true),
      task('ontem feita', DateTime(2026, 11, 3, 8), done: true),
      task('sexta', DateTime(2026, 11, 6, 18)),
      task('daqui a 8 dias', DateTime(2026, 11, 12, 18)),
      task('sem prazo', null),
    ], _now);
    expect(groups.today.tasks.map((t) => t.title), [
      'atrasada',
      'hoje',
      'hoje feita',
    ]);
    expect(groups.today.completed, 1);
    expect(groups.upcoming.tasks.map((t) => t.title), ['sexta']);
  });
}
