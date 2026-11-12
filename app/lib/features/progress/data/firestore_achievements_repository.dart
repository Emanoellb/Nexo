import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firestore_access.dart';
import 'achievements_repository.dart';

/// `users/{uid}/achievements/{id}` no Firestore: só `earnedAt` (carimbo do
/// servidor), com o id do catálogo (`achievementsCatalog`). As regras só
/// deixam criar (nunca alterar): o app confere antes se já ganhou.
class FirestoreAchievementsRepository implements AchievementsRepository {
  FirestoreAchievementsRepository(
    this._access, {
    required String? uid,
    required this.clock,
  }) : _user = UserDocs(uid);

  final FirestoreAccess _access;
  final UserDocs _user;

  /// Hora da medalha enquanto o carimbo do servidor não chega.
  final DateTime Function() clock;

  CollectionReference<Map<String, dynamic>> _earned(FirebaseFirestore db) =>
      _user.collection(db, 'achievements');

  @override
  Stream<List<EarnedAchievement>> watchEarned() {
    if (!_user.signedIn) return Stream.value(const []);
    return _access
        .watchDocs(_earned)
        .map(
          (docs) => [
            for (final doc in docs)
              EarnedAchievement(
                id: doc.id,
                earnedAt: timestampField(doc.data()?['earnedAt']) ?? clock(),
              ),
          ],
        );
  }

  @override
  Future<void> award(String id) async {
    final earned = await _access.run(
      (db) async => (await _earned(db).doc(id).snapshots().first).exists,
    );
    if (earned) return;
    await _access.send(
      (db) =>
          _earned(db).doc(id).set({'earnedAt': FieldValue.serverTimestamp()}),
    );
  }
}
