import 'package:flutter/foundation.dart';

/// Tipos de aviso do painel de notificações (aprovado em 04/11/2026).
enum NotificationKind {
  /// Entrega próxima de uma tarefa.
  dueSoon,

  /// Tarefa atrasada.
  overdue,

  /// Meta do dia de um plano.
  dailyGoal,

  /// Conquista ganha.
  achievement,
}

/// Para onde o toque leva. Na prototipação, à aba correspondente; as telas
/// de detalhe (tarefa, plano, dia) ainda não existem.
enum NotificationTarget { tasks, plans, calendar, profile }

@immutable
class NexoNotification {
  const NexoNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  NotificationTarget get target => switch (kind) {
    NotificationKind.dueSoon ||
    NotificationKind.overdue => NotificationTarget.tasks,
    NotificationKind.dailyGoal => NotificationTarget.plans,
    NotificationKind.achievement => NotificationTarget.profile,
  };

  NexoNotification copyWith({bool? read}) => NexoNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    read: read ?? this.read,
  );
}

/// Janela do painel ("Últimos 30 dias"), a mesma do TTL do histórico.
const notificationWindow = Duration(days: 30);

/// Não lidos primeiro; em cada grupo, os mais recentes primeiro.
List<NexoNotification> sortNotifications(Iterable<NexoNotification> items) =>
    [...items]..sort((a, b) {
      if (a.read != b.read) return a.read ? 1 : -1;
      return b.createdAt.compareTo(a.createdAt);
    });

/// "agora", "há 5 min", "há 2 h", "ontem", "há 3 dias".
String formatRelativeTime(DateTime at, DateTime now) {
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inHours < 1) return 'há ${diff.inMinutes} min';
  if (diff.inDays < 1) return 'há ${diff.inHours} h';
  if (diff.inDays == 1) return 'ontem';
  return 'há ${diff.inDays} dias';
}
