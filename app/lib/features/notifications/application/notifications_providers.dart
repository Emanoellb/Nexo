import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../../../core/data/firestore_access.dart';
import '../../auth/application/account_deletion.dart';
import '../../auth/application/auth_providers.dart';
import '../../plans/application/plan_today.dart';
import '../../plans/application/plans_providers.dart';
import '../../plans/domain/plan.dart';
import '../../plans/domain/plan_day_result.dart';
import '../../progress/application/achievements_providers.dart';
import '../../tasks/application/tasks_providers.dart';
import '../data/firestore_notifications_repository.dart';
import '../data/notifications_repository.dart';
import '../domain/nexo_notification.dart';
import '../domain/notification_history.dart';

/// Histórico do sino no Firestore (`users/{uid}/notifications`, regras
/// v0.10), com o uid verificado. Trocar de conta recria.
final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => FirestoreNotificationsRepository(
    ref.watch(firestoreAccessProvider),
    uid: ref.watch(verifiedUidProvider),
    clock: ref.watch(clockProvider),
  ),
);

final notificationsProvider = StreamProvider<List<NexoNotification>>(
  (ref) => ref.watch(notificationsRepositoryProvider).watchNotifications(),
);

/// Quantos avisos ainda não foram lidos (ponto no sino).
final unreadNotificationsProvider = Provider<int>(
  (ref) =>
      ref.watch(notificationsProvider).value?.where((n) => !n.read).length ?? 0,
);

/// Espera antes de gravar: junta as mudanças seguidas.
const notificationHistoryDelay = Duration(seconds: 1);

/// Grava no histórico os avisos que já aconteceram e ainda não estão lá
/// ([notificationHistoryAt]): ao abrir o app e a cada mudança nas tarefas,
/// nos planos e nas medalhas. O `main` escuta.
final notificationHistorySyncProvider = Provider<void>((ref) {
  if (ref.watch(verifiedUidProvider) == null) return;
  // Excluindo a conta: nada de avisos novos (o apagador já limpou ou vai
  // limpar `notifications`; um aviso gravado depois ficaria para trás).
  // Reconstruir aqui cancela o timer pendente.
  if (ref.watch(accountDeletionRunningProvider) ||
      ref.watch(
        userProfileProvider.select((p) => p.value?.deletionRequestedAt != null),
      )) {
    return;
  }
  final plans = ref.watch(plansProvider).value;
  final tasks = ref.watch(tasksProvider).value;
  final earned = ref.watch(earnedAchievementsProvider).value;
  if (plans == null || tasks == null || earned == null) return;

  final snapshots = <PlanSnapshot>[];
  for (final plan in plans) {
    if (plan.status != PlanStatus.active) continue;
    final snapshot = ref.watch(planSnapshotProvider(plan.id));
    if (snapshot == null) return;
    snapshots.add(snapshot);
  }

  final history = notificationHistoryAt(
    now: ref.read(clockProvider)(),
    plans: snapshots,
    tasks: tasks,
    earned: {for (final e in earned) e.id: e.earnedAt},
  );
  final repository = ref.read(notificationsRepositoryProvider);
  final timer = Timer(
    notificationHistoryDelay,
    () => unawaited(repository.record(history)),
  );
  ref.onDispose(timer.cancel);
});
