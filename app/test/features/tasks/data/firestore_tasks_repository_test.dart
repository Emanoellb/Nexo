import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/firestore_access.dart';
import 'package:nexo/features/tasks/data/firestore_tasks_repository.dart';
import 'package:nexo/features/tasks/domain/task.dart';
import 'package:nexo/features/tasks/domain/task_rules.dart';

import '../../../helpers/firestore_test_support.dart';

const _uid = 'u1';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreTasksRepository repository;

  CollectionReference<Map<String, dynamic>> tasks() =>
      db.collection('users').doc(_uid).collection('tasks');

  Future<Map<String, dynamic>> data(String id) async =>
      (await tasks().doc(id).get()).data()!;

  NexoTask draft({bool completed = false, DeliveryStatus? status}) => NexoTask(
    id: '',
    title: 'Lista 3',
    priority: TaskPriority.high,
    completed: completed,
    dueAt: DateTime(2026, 11, 12, 18),
    remindersMinutesBefore: const [TaskReminder.oneDay],
    deliveryStatus: status,
  );

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = FirestoreTasksRepository(
      FirestoreAccess.of(db),
      uid: _uid,
      clock: () => DateTime(2026, 11, 11, 10),
    );
  });

  test('criar pendente: completedAt null e só campos das regras', () async {
    final task = await repository.createTask(
      draft(status: DeliveryStatus.notStarted),
    );
    await settle();
    final saved = await data(task.id);
    expectValidCreate(
      saved,
      allowed: RulesFields.task,
      required: RulesFields.taskRequired,
    );
    expect(saved['completed'], isFalse);
    expect(saved.containsKey('completedAt'), isTrue);
    expect(saved['completedAt'], isNull);
    expect(saved['dueAt'], isA<Timestamp>());
    expect(saved['priority'], 'high');
    expect(saved['remindersMinutesBefore'], [TaskReminder.oneDay]);
  });

  test('criar já concluída: carimbo do servidor e entrega coerente', () async {
    final task = await repository.createTask(
      draft(completed: true, status: DeliveryStatus.delivered),
    );
    await settle();
    final saved = await data(task.id);
    expect(saved['completed'], isTrue);
    expect(saved['completedAt'], isA<Timestamp>());
    expect(saved['deliveryStatus'], 'delivered');
  });

  test('concluir e reabrir: carimbo, entrega e pontos', () async {
    final task = await repository.createTask(
      draft(status: DeliveryStatus.notStarted),
    );
    await settle();
    final pending = await agedData(tasks().doc(task.id));

    expect(await repository.setCompleted(task.id, true), 1);
    await settle();
    final done = await data(task.id);
    expect(changedKeys(pending, done), {
      'completed',
      'completedAt',
      'deliveryStatus',
      'updatedAt',
    });
    expect(done['completedAt'], isA<Timestamp>());
    expect(done['deliveryStatus'], 'delivered');

    expect(await repository.setCompleted(task.id, true), 0);

    expect(await repository.setCompleted(task.id, false), -1);
    await settle();
    final reopened = await data(task.id);
    expect(reopened['completedAt'], isNull);
    expect(reopened['deliveryStatus'], 'inProgress');
  });

  test('editar não mexe em completed nem completedAt', () async {
    final task = await repository.createTask(
      draft(completed: true, status: DeliveryStatus.delivered),
    );
    await settle();
    await tasks().doc(task.id).update({
      'createdAt': oldStamp,
      'updatedAt': oldStamp,
    });
    final before = await data(task.id);
    final current = (await repository.watchTasks().first).single;

    await repository.updateTask(
      current.copyWith(title: 'Lista 4', subjectId: () => 's1'),
    );
    await settle();
    final after = await data(task.id);
    expectValidUpdate(before, after, allowed: RulesFields.task);
    expect(changedKeys(before, after), {'title', 'subjectId', 'updatedAt'});
  });

  test('apagar: −1 se estava concluída, 0 se não', () async {
    final done = await repository.createTask(draft(completed: true));
    final open = await repository.createTask(draft());
    await settle();
    expect(await repository.deleteTask(done.id), -1);
    expect(await repository.deleteTask(open.id), 0);
    expect(await repository.deleteTask('nao-existe'), 0);
    await settle();
    expect((await tasks().get()).docs, isEmpty);
  });

  test('lista: pendentes por prazo, depois as concluídas', () async {
    await tasks().doc('a').set({
      'title': 'Sem prazo',
      'priority': 'none',
      'completed': false,
      'completedAt': null,
    });
    await tasks().doc('b').set({
      'title': 'Concluída',
      'priority': 'none',
      'completed': true,
      'completedAt': Timestamp.now(),
    });
    await tasks().doc('c').set({
      'title': 'Amanhã',
      'priority': 'low',
      'completed': false,
      'completedAt': null,
      'dueAt': Timestamp.fromDate(DateTime(2026, 11, 12)),
    });
    final list = await repository.watchTasks().first;
    expect([for (final t in list) t.id], ['c', 'a', 'b']);
  });

  test('tarefa antiga e documento fora do formato', () {
    final legacy = taskFromFirestore('t', {
      'title': 'Antiga',
      'priority': 'medium',
      'completed': false,
      'completedAt': null,
      'dueAt': Timestamp.fromDate(DateTime(2026, 11, 20)),
      'reminderMinutesBefore': 60,
    })!;
    expect(legacy.remindersMinutesBefore, [60]);
    expect(taskFromFirestore('t', {'priority': 'high'}), isNull);
  });
}
