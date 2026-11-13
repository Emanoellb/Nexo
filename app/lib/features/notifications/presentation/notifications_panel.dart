import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/data/clock.dart';
import '../../../core/ui/ui.dart';
import '../application/notifications_providers.dart';
import '../domain/nexo_notification.dart';

/// Conteúdo do painel de notificações, ligado aos avisos. Abrir o painel não
/// marca nada como lido; tocar num aviso marca só aquele e chama [onOpen];
/// o botão do cabeçalho marca todos.
class NotificationsPanel extends ConsumerWidget {
  const NotificationsPanel({
    super.key,
    required this.width,
    required this.arrowCenter,
    required this.onClose,
    required this.onOpen,
  });

  final double width;
  final double arrowCenter;
  final VoidCallback onClose;

  /// Leva ao destino do aviso (na prototipação, à aba correspondente).
  final ValueChanged<NexoNotification> onOpen;

  static IconData iconOf(NotificationKind kind) => switch (kind) {
    NotificationKind.dueSoon => LucideIcons.calendarClock,
    NotificationKind.overdue => LucideIcons.clockAlert,
    NotificationKind.dailyGoal => LucideIcons.target,
    NotificationKind.achievement => LucideIcons.trophy,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider).value ?? const [];
    final repository = ref.read(notificationsRepositoryProvider);
    final now = ref.read(clockProvider)();
    final hasUnread = items.any((n) => !n.read);

    return NexoNotificationPanel(
      width: width,
      arrowCenter: arrowCenter,
      onClose: onClose,
      onMarkAllRead: hasUnread ? repository.markAllRead : null,
      items: [
        for (final item in items)
          NexoNotificationItem(
            icon: iconOf(item.kind),
            title: item.title,
            body: item.body,
            time: formatRelativeTime(item.createdAt, now),
            unread: !item.read,
            onTap: () async {
              // Já lido: as regras não deixam gravar `readAt` de novo.
              if (!item.read) await repository.markRead(item.id);
              onOpen(item);
            },
          ),
      ],
    );
  }
}
