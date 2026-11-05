import 'dart:async';

import '../domain/nexo_notification.dart';

/// Histórico de avisos do usuário. A versão Firestore (com o TTL de 30 dias)
/// entra no bloco de integração (firebase-setup.md A13–A15). Os métodos
/// lançam `DataFailure` (core/data/data_failure.dart) nos erros.
abstract interface class NotificationsRepository {
  /// Avisos dos últimos 30 dias, não lidos primeiro.
  Stream<List<NexoNotification>> watchNotifications();

  /// Marca só este aviso como lido (tocar nele).
  Future<void> markRead(String id);

  /// "Marcar todas como lidas".
  Future<void> markAllRead();
}

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
  }) {
    final item = NexoNotification(
      id: 'aviso-${_nextId++}',
      kind: kind,
      title: title,
      body: body,
      createdAt: createdAt,
      read: read,
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

  @override
  Future<void> markRead(String id) async {
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

  void dispose() => _controller.close();
}
