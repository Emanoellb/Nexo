import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../data/notifications_repository.dart';
import '../domain/nexo_notification.dart';

/// Na prototipação, o fake (sem Firebase), preenchido pelos dados de exemplo.
final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  final repository = FakeNotificationsRepository(
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final notificationsProvider = StreamProvider<List<NexoNotification>>(
  (ref) => ref.watch(notificationsRepositoryProvider).watchNotifications(),
);

/// Quantos avisos ainda não foram lidos (ponto no sino).
final unreadNotificationsProvider = Provider<int>(
  (ref) =>
      ref.watch(notificationsProvider).value?.where((n) => !n.read).length ?? 0,
);
