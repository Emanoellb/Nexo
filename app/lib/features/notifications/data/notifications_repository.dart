import 'dart:async';

import '../domain/nexo_notification.dart';

/// Histórico de avisos do usuário. A versão Firestore (com o TTL de 30 dias)
/// entra na Etapa 5 (firebase-setup.md A13–A15). Os métodos
/// lançam `DataFailure` (core/data/data_failure.dart) nos erros.
abstract interface class NotificationsRepository {
  /// Avisos dos últimos 30 dias, não lidos primeiro.
  Stream<List<NexoNotification>> watchNotifications();

  /// Marca só este aviso como lido (tocar nele).
  Future<void> markRead(String id);

  /// "Marcar todas como lidas".
  Future<void> markAllRead();
}

/// Até a Etapa 5, nenhum aviso é gravado (a coleção `notifications`, com o
/// TTL de 30 dias, entra com as pendências A13–A15): a lista fica vazia.
class NoNotificationsRepository implements NotificationsRepository {
  const NoNotificationsRepository();

  @override
  Stream<List<NexoNotification>> watchNotifications() => Stream.value(const []);

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}
}
