import 'dart:async';

import 'package:nexo/features/notifications/data/notifications_repository.dart';
import 'package:nexo/features/notifications/domain/nexo_notification.dart';

/// Em memória para a prototipação, com exemplos fictícios.
class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository({required this.clock});

  final DateTime Function() clock;
  final _items = <String, NexoNotification>{};
  final _controller = StreamController<List<NexoNotification>>.broadcast();
  var _nextId = 1;

  List<NexoNotification> get _current {
    final since = clock().subtract(notificationWindow);
    return sortNotifications(
      _items.values.where((n) => n.createdAt.isAfter(since)),
    );
  }

  void _emit() => _controller.add(_current);

  /// Para os dados de exemplo e os testes.
  NexoNotification add({
    required NotificationKind kind,
    required String title,
    required String body,
    required DateTime createdAt,
    bool read = false,
    String? taskId,
    String? planId,
  }) {
    final item = NexoNotification(
      id: 'aviso-${_nextId++}',
      kind: kind,
      title: title,
      body: body,
      createdAt: createdAt,
      read: read,
      taskId: taskId,
      planId: planId,
    );
    _items[item.id] = item;
    _emit();
    return item;
  }

  @override
  Stream<List<NexoNotification>> watchNotifications() async* {
    yield _current;
    yield* _controller.stream;
  }

  /// Para os testes: chamado a cada `markRead`.
  void Function(String id)? onMarkRead;

  @override
  Future<void> markRead(String id) async {
    onMarkRead?.call(id);
    final item = _items[id];
    if (item == null || item.read) return;
    _items[id] = item.copyWith(read: true);
    _emit();
  }

  @override
  Future<void> markAllRead() async {
    for (final MapEntry(:key, :value) in [..._items.entries]) {
      if (!value.read) _items[key] = value.copyWith(read: true);
    }
    _emit();
  }

  @override
  Future<void> record(List<NexoNotification> notices) async {
    var changed = false;
    for (final notice in notices) {
      if (_items.containsKey(notice.id)) continue;
      _items[notice.id] = notice;
      changed = true;
    }
    if (changed) _emit();
  }

  void dispose() => _controller.close();
}
