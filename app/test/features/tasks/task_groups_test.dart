import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/features/tasks/domain/task.dart';
import 'package:nexo/features/tasks/domain/task_groups.dart';
import 'package:nexo/features/tasks/domain/task_rules.dart';
import 'package:nexo/features/tasks/presentation/task_text.dart';

// Quarta, 04/11/2026, 10:00 (semana do Nexo: domingo 01 a sábado 07).
final _now = DateTime(2026, 11, 4, 10);

NexoTask _task(
  String id, {
  DateTime? due,
  bool completed = false,
  DateTime? completedAt,
  String? subjectId,
  TaskPriority priority = TaskPriority.none,
  String? title,
}) => NexoTask(
  id: id,
  title: title ?? 'Tarefa $id',
  dueAt: due,
  completed: completed,
  completedAt: completedAt,
  subjectId: subjectId,
  priority: priority,
);

void main() {
  group('seção por prazo', () {
    TaskSection? of(NexoTask t) => taskSectionOf(t, _now);

    test('atrasada, hoje, amanhã, esta semana, depois e sem prazo', () {
      expect(
        of(_task('a', due: DateTime(2026, 11, 3, 23, 59))),
        TaskSection.overdue,
      );
      // Hoje, mas já passou do horário: atrasada.
      expect(
        of(_task('b', due: DateTime(2026, 11, 4, 8))),
        TaskSection.overdue,
      );
      expect(of(_task('c', due: DateTime(2026, 11, 4, 18))), TaskSection.today);
      expect(
        of(_task('d', due: DateTime(2026, 11, 5, 9))),
        TaskSection.tomorrow,
      );
      // Sábado fecha a semana (domingo a sábado).
      expect(
        of(_task('e', due: DateTime(2026, 11, 7, 20))),
        TaskSection.thisWeek,
      );
      expect(of(_task('f', due: DateTime(2026, 11, 8, 9))), TaskSection.later);
      expect(of(_task('g')), TaskSection.noDue);
    });

    test('concluídas: só as dos últimos 7 dias (hoje incluso)', () {
      final done = DateTime(2026, 11, 4, 9);
      expect(
        of(_task('a', completed: true, completedAt: done)),
        TaskSection.completed,
      );
      expect(
        of(_task('b', completed: true, completedAt: DateTime(2026, 10, 29))),
        TaskSection.completed,
      );
      expect(
        of(_task('c', completed: true, completedAt: DateTime(2026, 10, 28))),
        isNull,
      );
      // Sem carimbo ainda: acabou de ser concluída.
      expect(of(_task('d', completed: true)), TaskSection.completed);
    });
  });

  test('grupos na ordem da tela, sem vazios, ordenados', () {
    final groups = groupTasksByDue([
      _task('late', due: DateTime(2026, 11, 8, 9)),
      _task('t2', due: DateTime(2026, 11, 4, 21)),
      _task('t1', due: DateTime(2026, 11, 4, 18)),
      _task(
        't1high',
        due: DateTime(2026, 11, 4, 18),
        priority: TaskPriority.high,
      ),
      _task('n1', title: 'b'),
      _task('n2', title: 'a', priority: TaskPriority.high),
      _task('c1', completed: true, completedAt: DateTime(2026, 11, 2)),
      _task('c2', completed: true, completedAt: DateTime(2026, 11, 3)),
    ], _now);
    expect(
      [for (final g in groups) g.section],
      [
        TaskSection.today,
        TaskSection.later,
        TaskSection.noDue,
        TaskSection.completed,
      ],
    );
    // Mesmo horário: prioridade alta primeiro.
    expect([for (final t in groups[0].tasks) t.id], ['t1high', 't1', 't2']);
    expect([for (final t in groups[2].tasks) t.id], ['n2', 'n1']);
    // Concluídas: a mais recente primeiro.
    expect([for (final t in groups[3].tasks) t.id], ['c2', 'c1']);
  });

  test('abas: Hoje com as atrasadas no topo; Próximas com sem prazo', () {
    final byTab = tasksByTab([
      _task('today', due: DateTime(2026, 11, 4, 18)),
      _task('late', due: DateTime(2026, 11, 3, 9)),
      _task('nodue'),
      _task('tomorrow', due: DateTime(2026, 11, 5, 9)),
      _task('done', completed: true, completedAt: DateTime(2026, 11, 4, 9)),
    ], _now);
    expect([for (final t in byTab[TaskTab.today]!) t.id], ['late', 'today']);
    expect(
      [for (final t in byTab[TaskTab.upcoming]!) t.id],
      ['tomorrow', 'nodue'],
    );
    expect([for (final t in byTab[TaskTab.completed]!) t.id], ['done']);
  });

  group('progresso da disciplina', () {
    test('conta entregas e acha a próxima (a atrasada mais antiga)', () {
      final p = subjectProgressOf('s1', [
        _task('a', subjectId: 's1', completed: true, completedAt: _now),
        _task('b', subjectId: 's1', due: DateTime(2026, 11, 6, 9)),
        _task('c', subjectId: 's1', due: DateTime(2026, 11, 3, 23, 59)),
        _task('d', subjectId: 's1'),
        _task('e', subjectId: 's2', due: DateTime(2026, 11, 1)),
      ], _now);
      expect(p.done, 1);
      expect(p.total, 4);
      expect(p.next?.id, 'c');
      expect(p.nextOverdue, isTrue);
    });

    test('sem pendentes com prazo: sem próxima', () {
      final p = subjectProgressOf('s1', [_task('d', subjectId: 's1')], _now);
      expect(p.next, isNull);
      expect(p.nextOverdue, isFalse);
    });

    test('texto da próxima entrega', () {
      expect(
        nextDeliveryText('Lista 3', DateTime(2026, 11, 5, 9), _now),
        'Próxima: Lista 3 · amanhã',
      );
      expect(
        nextDeliveryText('Lista 3', DateTime(2026, 11, 6, 9), _now),
        'Próxima: Lista 3 · sex',
      );
      expect(
        nextDeliveryText('Lista 3', DateTime(2026, 11, 3, 23, 59), _now),
        'Próxima: Lista 3 · atrasada',
      );
      expect(
        nextDeliveryText('Lista 3', DateTime(2026, 11, 20, 9), _now),
        'Próxima: Lista 3 · 20/11',
      );
    });
  });

  test('adiar: amanhã no mesmo horário', () {
    expect(
      postponedDue(DateTime(2026, 11, 3, 23, 59), now: _now),
      DateTime(2026, 11, 5, 23, 59),
    );
  });
}
