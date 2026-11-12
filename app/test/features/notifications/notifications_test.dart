import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/ui/ui.dart';
import 'package:nexo/features/notifications/domain/nexo_notification.dart';

import '../../fakes/fakes.dart';

final _now = DateTime(2026, 11, 4, 12);

void main() {
  group('FakeNotificationsRepository', () {
    late FakeNotificationsRepository repo;

    setUp(() {
      repo = FakeNotificationsRepository(clock: () => _now);
      addTearDown(repo.dispose);
    });

    NexoNotification add(String title, Duration ago, {bool read = false}) =>
        repo.add(
          kind: NotificationKind.dueSoon,
          title: title,
          body: '…',
          createdAt: _now.subtract(ago),
          read: read,
        );

    test('não lidos primeiro; em cada grupo, os mais recentes', () async {
      add('lido novo', const Duration(hours: 1), read: true);
      add('não lido antigo', const Duration(days: 2));
      add('não lido novo', const Duration(hours: 3));
      final titles = (await repo.watchNotifications().first).map(
        (n) => n.title,
      );
      expect(titles, ['não lido novo', 'não lido antigo', 'lido novo']);
    });

    test('só os últimos 30 dias', () async {
      add('dentro', const Duration(days: 29));
      add('fora', const Duration(days: 31));
      final titles = (await repo.watchNotifications().first).map(
        (n) => n.title,
      );
      expect(titles, ['dentro']);
    });

    test('tocar marca só aquele; o botão marca todos', () async {
      final a = add('a', const Duration(hours: 1));
      add('b', const Duration(hours: 2));

      await repo.markRead(a.id);
      var items = await repo.watchNotifications().first;
      expect(items.where((n) => !n.read).map((n) => n.title), ['b']);

      await repo.markAllRead();
      items = await repo.watchNotifications().first;
      expect(items.every((n) => n.read), isTrue);
    });
  });

  test('cada tipo leva ao seu destino', () {
    NotificationTarget targetOf(NotificationKind kind) => NexoNotification(
      id: 'x',
      kind: kind,
      title: 't',
      body: 'b',
      createdAt: _now,
    ).target;
    expect(targetOf(NotificationKind.dueSoon), NotificationTarget.tasks);
    expect(targetOf(NotificationKind.overdue), NotificationTarget.tasks);
    expect(targetOf(NotificationKind.dailyGoal), NotificationTarget.plans);
    expect(targetOf(NotificationKind.achievement), NotificationTarget.profile);
  });

  test('tempo relativo', () {
    String ago(Duration d) => formatRelativeTime(_now.subtract(d), _now);
    expect(ago(const Duration(seconds: 20)), 'agora');
    expect(ago(const Duration(minutes: 5)), 'há 5 min');
    expect(ago(const Duration(hours: 2)), 'há 2 h');
    expect(ago(const Duration(days: 1, hours: 3)), 'ontem');
    expect(ago(const Duration(days: 4)), 'há 4 dias');
  });

  test('iniciais do avatar', () {
    expect(initialsOf('Ana Souza'), 'AS');
    expect(initialsOf('ana maria souza'), 'AS');
    expect(initialsOf('Ana'), 'A');
    expect(initialsOf('  '), '');
  });
}
