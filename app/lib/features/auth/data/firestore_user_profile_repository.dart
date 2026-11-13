import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firestore_access.dart';
import '../domain/auth_user.dart';
import 'auth_repository.dart';

/// `users/{uid}` no Firestore (contrato em firestore-rules.md §4, regras
/// v0.9):
/// - o Cadastro e a 03b criam o documento com o aceite e esperam o
///   servidor;
/// - os ajustes do dia a dia (tutorial, pontos, plano principal, nome,
///   limite de tarefas, aviso da manhã) não esperam ([FirestoreAccess.send]);
/// - toda gravação renova `updatedAt` com o carimbo do servidor, como as
///   regras pedem.
///
/// A leitura exige o e-mail verificado: quem escuta é o
/// `userProfileProvider`, só depois da verificação.
class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository(this._access);

  final FirestoreAccess _access;

  static DocumentReference<Map<String, dynamic>> _doc(
    FirebaseFirestore db,
    String uid,
  ) => db.collection('users').doc(uid);

  @override
  Stream<UserProfile?> watchProfile(String uid) => _access
      .watchDoc((db) => _doc(db, uid))
      .map((snapshot) => userProfileFromFirestore(snapshot.data()));

  @override
  Future<void> createProfile(String uid, NewUserProfile profile) => _access.run(
    (db) => _doc(db, uid).set(newUserProfileToFirestore(profile)),
  );

  /// Ajuste sem esperar o servidor, com o `updatedAt` que as regras pedem.
  Future<void> _change(String uid, Map<String, Object?> fields) => _access.send(
    (db) => _doc(db, uid).update({...fields, ...updatedStamp()}),
  );

  @override
  Future<void> markTutorialSeen(String uid) =>
      _change(uid, {'tutorialSeen': true});

  /// Soma pelo `increment` (vale offline e não perde soma de outra
  /// gravação), mas sem sair de 0 a [UserProfile.maxPoints]: fora disso, as
  /// regras recusariam.
  @override
  Future<void> addPoints(String uid, int delta) async {
    if (delta == 0) return;
    // O valor mais recente que o aparelho conhece (o cache primeiro).
    final profile = await watchProfile(uid).first;
    if (profile == null) return;
    final next = (profile.points + delta).clamp(0, UserProfile.maxPoints);
    final change = next - profile.points;
    if (change == 0) return;
    await _change(uid, {'points': FieldValue.increment(change)});
  }

  @override
  Future<void> setPrimaryPlan(String uid, String? planId) =>
      _change(uid, {'primaryPlanId': planId});

  @override
  Future<void> updateDisplayName(String uid, String name) =>
      _change(uid, {'displayName': name.trim()});

  @override
  Future<void> setOverloadThreshold(String uid, int threshold) =>
      _change(uid, {'overloadThreshold': threshold});

  /// Espera o servidor (bug de 12/11/2026: no aparelho, a gravação voltava
  /// atrás em silêncio). Recusada, lança `DataFailure` e o Perfil avisa.
  @override
  Future<void> setMorningSummary(String uid, MorningSummary summary) =>
      _access.run(
        (db) => _doc(db, uid).update({
          'morningSummary': {'enabled': summary.enabled, 'time': summary.time},
          ...updatedStamp(),
        }),
      );

  /// Uma vez só: as regras recusam trocar o carimbo depois de gravado.
  /// Espera o servidor, porque a exclusão dos dados depende dele.
  @override
  Future<void> markDeletionRequested(String uid) => _access.run((db) async {
    final doc = _doc(db, uid);
    final snapshot = await doc.snapshots().first;
    final data = snapshot.data();
    if (data == null || data.containsKey('deletionRequestedAt')) return;
    await doc.update({
      'deletionRequestedAt': FieldValue.serverTimestamp(),
      ...updatedStamp(),
    });
  });

  @override
  Future<void> deleteProfile(String uid) =>
      _access.run((db) => _doc(db, uid).delete());
}

/// O documento que o Cadastro e a 03b criam. Só os campos de criação das
/// regras (`userCreateFields`): o limite de tarefas e o aviso da manhã
/// ficam vazios (o app usa o padrão) até a pessoa mudar no Perfil.
Map<String, Object?> newUserProfileToFirestore(NewUserProfile profile) => {
  'displayName': profile.displayName,
  'birthDate': profile.birthDate.toIso(),
  'timeZone': profile.timeZone,
  'tutorialSeen': false,
  'points': 0,
  'consents': {
    'termsVersion': profile.consents.termsVersion,
    'privacyVersion': profile.consents.privacyVersion,
    'acceptedAt': FieldValue.serverTimestamp(),
  },
  ...createdStamps(),
};

/// `users/{uid}` → [UserProfile]; `null` sem documento. Campo ausente ou de
/// outro tipo vira o padrão do app, sem quebrar a leitura. O
/// `deletionRequestedAt` pendente chega estimado ([FirestoreAccess.watchDoc]).
UserProfile? userProfileFromFirestore(Map<String, dynamic>? data) {
  if (data == null) return null;
  final displayName = data['displayName'];
  final primaryPlanId = data['primaryPlanId'];
  return UserProfile(
    displayName: displayName is String ? displayName : '',
    tutorialSeen: data['tutorialSeen'] == true,
    points: intField(data['points']) ?? 0,
    primaryPlanId: primaryPlanId is String ? primaryPlanId : null,
    overloadThreshold: intField(data['overloadThreshold']),
    morningSummary: _morningSummary(data['morningSummary']),
    birthDate: localDateField(data['birthDate']),
    deletionRequestedAt: timestampField(data['deletionRequestedAt']),
  );
}

MorningSummary _morningSummary(Object? value) {
  if (value is Map) {
    final enabled = value['enabled'];
    final time = value['time'];
    if (enabled is bool && time is String) {
      return MorningSummary(enabled: enabled, time: time);
    }
  }
  return MorningSummary.standard;
}
