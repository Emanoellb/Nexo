import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/features/auth/application/account_deletion.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/notifications/application/notifications_providers.dart';
import 'package:nexo/features/notifications/domain/nexo_notification.dart';
import 'package:nexo/features/tasks/application/tasks_providers.dart';
import 'package:nexo/features/tasks/domain/task.dart';

import '../../fakes/fakes.dart';

/// Conta o que o app grava no histórico.
class _CountingNotifications extends FakeNotificationsRepository {
  _CountingNotifications({required super.clock});

  final recorded = <String>[];

  @override
  Future<void> record(List<NexoNotification> notices) async {
    recorded.addAll([for (final n in notices) n.id]);
    await super.record(notices);
  }
}

// Quarta, 11/11/2026, 10:00.
final _now = DateTime(2026, 11, 11, 10);

Future<void> _wait() => Future<void>.delayed(
  notificationHistoryDelay + const Duration(milliseconds: 200),
);

void main() {
  Future<(ProviderContainer, _CountingNotifications)> setUpApp() async {
    final notifications = _CountingNotifications(clock: () => _now);
    final container = ProviderContainer(
      overrides: [
        ...fakeBackend(
          auth: FakeAuthRepository.signedIn(),
          notifications: notifications,
        ),
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    addTearDown(container.dispose);
    container.listen(notificationHistorySyncProvider, (_, _) {});
    await container.read(authStateProvider.future);
    return (container, notifications);
  }

  test('grava a tarefa atrasada no histórico', () async {
    final (container, notifications) = await setUpApp();
    final task = await container
        .read(tasksRepositoryProvider)
        .createTask(
          NexoTask(id: '', title: 'Lista 3', dueAt: DateTime(2026, 11, 11, 9)),
        );
    await _wait();
    expect(notifications.recorded, contains('overdue_${task.id}'));
  });

  test('excluindo a conta, nada é gravado', () async {
    final (container, notifications) = await setUpApp();
    container.read(accountDeletionRunningProvider.notifier).set(true);
    await container
        .read(tasksRepositoryProvider)
        .createTask(
          NexoTask(id: '', title: 'Lista 3', dueAt: DateTime(2026, 11, 11, 9)),
        );
    await _wait();
    expect(notifications.recorded, isEmpty);
  });
}
