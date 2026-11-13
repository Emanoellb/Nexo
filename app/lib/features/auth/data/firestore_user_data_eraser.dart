import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firestore_access.dart';
import '../../plans/data/firestore_plans_repository.dart';
import '../application/account_deletion.dart';

/// Excluir conta: apaga os dados de `users/{uid}` no Firestore, em lotes de
/// até 500, liberado pelo `deletionRequestedAt` já gravado (regras v0.9):
/// 1. limpa o `primaryPlanId` (as regras não deixam apagar o plano para o
///    qual ele aponta);
/// 2. cada plano: as subcoleções e o plano;
/// 3. tarefas, disciplinas, objetivos, medalhas e o histórico do sino.
///
/// O `users/{uid}` sai depois (`AccountDeletion.finish`) e a conta do Auth
/// por último. Lê do servidor: sem internet, falha e a tela 09 oferece
/// "Tentar de novo". Se o app fechar no meio, o próximo login volta à tela
/// 09 (pelo `deletionRequestedAt`) e retoma. Repetir é seguro: apaga o que
/// sobrou.
class FirestoreUserDataEraser implements UserDataEraser {
  FirestoreUserDataEraser(this._access);

  final FirestoreAccess _access;

  /// Coleções de `users/{uid}` fora os planos.
  static const collections = [
    'tasks',
    'subjects',
    'goals',
    'achievements',
    'notifications',
  ];

  static const _server = GetOptions(source: Source.server);

  @override
  Future<void> eraseAll(String uid) async {
    final user = UserDocs(uid);
    final planIds = await _access.run((db) async {
      final profile = await user.user(db).get(_server);
      if (profile.data()?['primaryPlanId'] != null) {
        await user.user(db).update({'primaryPlanId': null, ...updatedStamp()});
      }
      final plans = await user.collection(db, 'plans').get(_server);
      return [for (final doc in plans.docs) doc.id];
    });

    final plans = FirestorePlansRepository(
      _access,
      uid: uid,
      clock: DateTime.now,
    );
    for (final id in planIds) {
      await plans.purgePlan(id);
    }

    await _access.run((db) async {
      for (final name in collections) {
        await deleteAllDocs(db, user.collection(db, name));
      }
    });
  }
}
