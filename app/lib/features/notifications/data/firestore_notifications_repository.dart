import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firestore_access.dart';
import '../domain/nexo_notification.dart';
import 'notifications_repository.dart';

/// `users/{uid}/notifications` no Firestore (histórico do sino, regras
/// v0.10):
/// - lê os avisos dos últimos 30 dias, do mais novo ao mais antigo. O TTL
///   apaga os vencidos com atraso, então o app filtra;
/// - lido = `readAt` gravado (hora do servidor, uma vez). Tocar num aviso
///   marca só ele; o ícone do painel marca todos num lote;
/// - grava só o aviso que ainda não existe: as regras recusam gravar de
///   novo, porque reiniciaria o `createdAt` e o TTL.
///
/// Gravações sem esperar o servidor ([FirestoreAccess.send]).
class FirestoreNotificationsRepository implements NotificationsRepository {
  FirestoreNotificationsRepository(
    this._access, {
    required String? uid,
    required this.clock,
  }) : _user = UserDocs(uid);

  final FirestoreAccess _access;
  final UserDocs _user;

  /// "Agora" da janela de 30 dias.
  final DateTime Function() clock;

  CollectionReference<Map<String, dynamic>> _notifications(
    FirebaseFirestore db,
  ) => _user.collection(db, 'notifications');

  @override
  Stream<List<NexoNotification>> watchNotifications() {
    if (!_user.signedIn) return Stream.value(const []);
    final since = Timestamp.fromDate(clock().subtract(notificationWindow));
    return _access
        .watchDocs(
          (db) =>
              _notifications(db)
                  .where('createdAt', isGreaterThanOrEqualTo: since)
                  .orderBy('createdAt', descending: true),
        )
        .map((docs) {
          // A consulta guarda a janela de quando abriu; com o app aberto por
          // dias, o filtro da hora atual tira os que passaram de 30 dias.
          final now = clock();
          final since = now.subtract(notificationWindow);
          return sortNotifications(
            [
              for (final doc in docs)
                ?notificationFromFirestore(doc.id, doc.data(), now: now),
            ].where((n) => !n.createdAt.isBefore(since)),
          );
        });
  }

  @override
  Future<void> markRead(String id) => _access.send(
    (db) =>
        _notifications(db)
            .doc(id)
            .update({'readAt': FieldValue.serverTimestamp()}),
  );

  @override
  Future<void> markAllRead() async {
    final unread = [
      for (final n in await watchNotifications().first)
        if (!n.read) n.id,
    ];
    if (unread.isEmpty) return;
    await _access.send((db) {
      final batch = db.batch();
      for (final id in unread) {
        batch.update(_notifications(db).doc(id), {
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      return batch.commit();
    });
  }

  /// Ids já conferidos nesta conta (existem ou acabaram de ser gravados):
  /// não são lidos de novo a cada mudança nos dados.
  final _known = <String>{};

  /// Uma gravação de cada vez: duas quase juntas leriam o mesmo "não
  /// existe" e a segunda seria recusada.
  Future<void> _queue = Future<void>.value();

  @override
  Future<void> record(List<NexoNotification> notices) {
    final result = _queue.then((_) => _record(notices));
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _record(List<NexoNotification> notices) async {
    if (!_user.signedIn) return;
    for (final notice in notices) {
      if (_known.contains(notice.id)) continue;
      // O documento como o aparelho o conhece (o cache primeiro).
      final exists = await _access.run(
        (db) async =>
            (await _notifications(db).doc(notice.id).snapshots().first).exists,
      );
      _known.add(notice.id);
      if (exists) continue;
      // Um por gravação: a recusa de um não derruba os outros.
      await _access.send(
        (db) =>
            _notifications(db)
                .doc(notice.id)
                .set(notificationToFirestore(notice)),
      );
    }
  }
}

/// Os campos do contrato v0.10 (`createdAt` do servidor, `readAt` nulo).
Map<String, Object?> notificationToFirestore(NexoNotification notice) => {
  'type': notice.kind.name,
  'title': notice.title,
  'body': notice.body,
  'taskId': ?notice.taskId,
  'planId': ?notice.planId,
  'day': ?notice.day,
  'achievementId': ?notice.achievementId,
  'createdAt': FieldValue.serverTimestamp(),
  'readAt': null,
};

/// `notifications/{id}` → [NexoNotification]; `null` fora do formato.
/// `createdAt` pendente (gravado agora, sem estimativa) vale [now].
NexoNotification? notificationFromFirestore(
  String id,
  Map<String, dynamic>? data, {
  required DateTime now,
}) {
  if (data == null) return null;
  final kind = NotificationKind.values
      .where((k) => k.name == data['type'])
      .firstOrNull;
  final title = data['title'];
  final body = data['body'];
  if (kind == null || title is! String || body is! String) return null;
  return NexoNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: timestampField(data['createdAt']) ?? now,
    read: data['readAt'] != null,
    taskId: data['taskId'] as String?,
    planId: data['planId'] as String?,
    day: data['day'] as String?,
    achievementId: data['achievementId'] as String?,
  );
}
