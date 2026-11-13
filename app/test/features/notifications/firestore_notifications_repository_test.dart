import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/firestore_access.dart';
import 'package:nexo/features/notifications/data/firestore_notifications_repository.dart';
import 'package:nexo/features/notifications/domain/nexo_notification.dart';

import '../../helpers/firestore_test_support.dart';

const _uid = 'u1';
final _now = DateTime(2026, 11, 13, 10);

/// Campos do contrato v0.10 (`notifications`).
const _fields = {
  'type',
  'title',
  'body',
  'taskId',
  'planId',
  'day',
  'achievementId',
  'createdAt',
  'readAt',
};

NexoNotification _overdue(String taskId) => NexoNotification(
  id: 'overdue_$taskId',
  kind: NotificationKind.overdue,
  title: 'Lista 3',
  body: 'A entrega era hoje às 09:00.',
  createdAt: _now,
  taskId: taskId,
);

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreNotificationsRepository repository;

  CollectionReference<Map<String, dynamic>> col() =>
      db.collection('users').doc(_uid).collection('notifications');

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = FirestoreNotificationsRepository(
      FirestoreAccess.of(db),
      uid: _uid,
      clock: () => _now,
    );
  });

  test('grava nos campos do contrato, uma vez só por evento', () async {
    await repository.record([
      _overdue('t1'),
      NexoNotification(
        id: 'dailyGoal_p1_2026-11-13',
        kind: NotificationKind.dailyGoal,
        title: 'Concurso',
        body: 'A meta de hoje ficou em aberto: faltam 30 min.',
        createdAt: _now,
        planId: 'p1',
        day: '2026-11-13',
      ),
    ]);
    await settle();
    final overdue = (await col().doc('overdue_t1').get()).data()!;
    expect(overdue.keys.toSet().difference(_fields), isEmpty);
    expect(overdue['type'], 'overdue');
    expect(overdue['taskId'], 't1');
    expect(overdue.containsKey('planId'), isFalse);
    expect(overdue['createdAt'], isA<Timestamp>());
    expect(overdue.containsKey('readAt'), isTrue);
    expect(overdue['readAt'], isNull);
    final goal = (await col().doc('dailyGoal_p1_2026-11-13').get()).data()!;
    expect(goal['planId'], 'p1');
    expect(goal['day'], '2026-11-13');
    expect(goal.containsKey('taskId'), isFalse);

    // De novo: nada muda (as regras recusariam regravar).
    final createdAt = overdue['createdAt'];
    await repository.record([_overdue('t1')]);
    await settle();
    expect(
      (await col().doc('overdue_t1').get()).data()!['createdAt'],
      createdAt,
    );
  });

  test('lista os últimos 30 dias, do mais novo; lido com readAt', () async {
    await col().doc('overdue_velho').set({
      'type': 'overdue',
      'title': 'Velho',
      'body': 'x',
      'taskId': 'velho',
      'createdAt': Timestamp.fromDate(_now.subtract(const Duration(days: 31))),
      'readAt': null,
    });
    await col().doc('overdue_a').set({
      'type': 'overdue',
      'title': 'A',
      'body': 'x',
      'taskId': 'a',
      'createdAt': Timestamp.fromDate(_now.subtract(const Duration(days: 2))),
      'readAt': null,
    });
    await col().doc('overdue_b').set({
      'type': 'overdue',
      'title': 'B',
      'body': 'x',
      'taskId': 'b',
      'createdAt': Timestamp.fromDate(_now.subtract(const Duration(days: 1))),
      'readAt': Timestamp.fromDate(_now),
    });
    final items = await repository.watchNotifications().first;
    // Não lidos primeiro; sem o de 31 dias.
    expect([for (final n in items) n.id], ['overdue_a', 'overdue_b']);
    expect(items.last.read, isTrue);
    expect(items.first.taskId, 'a');
  });

  test('marcar um e marcar todos gravam readAt', () async {
    await repository.record([_overdue('t1'), _overdue('t2')]);
    await settle();
    await repository.markRead('overdue_t1');
    await settle();
    expect(
      (await col().doc('overdue_t1').get()).data()!['readAt'],
      isA<Timestamp>(),
    );
    expect((await col().doc('overdue_t2').get()).data()!['readAt'], isNull);

    await repository.markAllRead();
    await settle();
    expect(
      (await col().doc('overdue_t2').get()).data()!['readAt'],
      isA<Timestamp>(),
    );
  });

  test('um aviso que já existe não impede os outros', () async {
    await col().doc('overdue_t1').set({
      'type': 'overdue',
      'title': 'Antigo',
      'body': 'x',
      'taskId': 't1',
      'createdAt': Timestamp.fromDate(_now),
      'readAt': null,
    });
    await repository.record([_overdue('t1'), _overdue('t2')]);
    await settle();
    expect((await col().doc('overdue_t1').get()).data()!['title'], 'Antigo');
    expect((await col().doc('overdue_t2').get()).exists, isTrue);
  });

  test('a janela de 30 dias acompanha a hora atual', () async {
    var now = _now;
    final moving = FirestoreNotificationsRepository(
      FirestoreAccess.of(db),
      uid: _uid,
      clock: () => now,
    );
    await col().doc('overdue_a').set({
      'type': 'overdue',
      'title': 'A',
      'body': 'x',
      'taskId': 'a',
      'createdAt': Timestamp.fromDate(_now.subtract(const Duration(days: 29))),
      'readAt': null,
    });
    final seen = <int>[];
    final sub = moving.watchNotifications().listen((l) => seen.add(l.length));
    addTearDown(sub.cancel);
    await settle();
    expect(seen.last, 1);
    now = _now.add(const Duration(days: 2));
    await col().doc('overdue_a').update({'body': 'y'});
    await settle();
    expect(seen.last, 0);
  });
}
