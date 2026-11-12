import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notifications_repository.dart';
import '../domain/nexo_notification.dart';

/// Sem avisos gravados até a Etapa 5 (coleção `notifications`): o sino fica
/// vazio.
final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => const NoNotificationsRepository(),
);

final notificationsProvider = StreamProvider<List<NexoNotification>>(
  (ref) => ref.watch(notificationsRepositoryProvider).watchNotifications(),
);

/// Quantos avisos ainda não foram lidos (ponto no sino).
final unreadNotificationsProvider = Provider<int>(
  (ref) =>
      ref.watch(notificationsProvider).value?.where((n) => !n.read).length ?? 0,
);
