import 'dart:async';

import '../domain/nexo_notification.dart';

/// Histórico de avisos do usuário (`users/{uid}/notifications`, regras
/// v0.10, com o TTL de 30 dias). Os métodos lançam `DataFailure`
/// (core/data/data_failure.dart) nos erros.
abstract interface class NotificationsRepository {
  /// Avisos dos últimos 30 dias, não lidos primeiro.
  Stream<List<NexoNotification>> watchNotifications();

  /// Marca só este aviso como lido (tocar nele).
  Future<void> markRead(String id);

  /// "Marcar todas como lidas".
  Future<void> markAllRead();

  /// Grava os avisos de [notices] que ainda não existem (o id é fixo por
  /// evento; gravar de novo o mesmo aviso é recusado pelas regras).
  Future<void> record(List<NexoNotification> notices);
}
