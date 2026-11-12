import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/firestore_access.dart';
import 'package:nexo/features/auth/data/firestore_user_data_eraser.dart';
import 'package:nexo/features/plans/data/firestore_plans_repository.dart';

const _uid = 'u1';

void main() {
  late FakeFirebaseFirestore db;

  DocumentReference<Map<String, dynamic>> user() =>
      db.collection('users').doc(_uid);

  Future<void> seed() async {
    await user().set({
      'displayName': 'Bia',
      'primaryPlanId': 'p1',
      'deletionRequestedAt': Timestamp.now(),
    });
    for (final planId in ['p1', 'p2']) {
      final plan = user().collection('plans').doc(planId);
      await plan.set({'name': planId, 'status': 'active'});
      for (final name in FirestorePlansRepository.children) {
        await plan.collection(name).doc('x').set({'a': 1});
        await plan.collection(name).doc('y').set({'a': 2});
      }
    }
    for (final name in FirestoreUserDataEraser.collections) {
      await user().collection(name).doc('x').set({'a': 1});
    }
    // Outra conta não é tocada.
    await db.collection('users').doc('outro').collection('tasks').doc('t').set({
      'a': 1,
    });
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    await seed();
  });

  test('apaga planos (com tudo dentro), tarefas, disciplinas, objetivos e '
      'medalhas; o users/{uid} fica para depois', () async {
    await FirestoreUserDataEraser(FirestoreAccess.of(db)).eraseAll(_uid);

    final plans = await user().collection('plans').get();
    expect(plans.docs, isEmpty);
    for (final planId in ['p1', 'p2']) {
      for (final name in FirestorePlansRepository.children) {
        final docs = await user()
            .collection('plans')
            .doc(planId)
            .collection(name)
            .get();
        expect(docs.docs, isEmpty, reason: '$planId/$name');
      }
    }
    for (final name in FirestoreUserDataEraser.collections) {
      expect((await user().collection(name).get()).docs, isEmpty, reason: name);
    }

    final profile = (await user().get()).data()!;
    // As regras não deixam apagar o plano principal: limpo antes.
    expect(profile['primaryPlanId'], isNull);
    expect(profile['deletionRequestedAt'], isA<Timestamp>());

    final other = await db
        .collection('users')
        .doc('outro')
        .collection('tasks')
        .get();
    expect(other.docs, hasLength(1));
  });

  test('repetir é seguro (retomada depois de fechar no meio)', () async {
    final eraser = FirestoreUserDataEraser(FirestoreAccess.of(db));
    await eraser.eraseAll(_uid);
    await eraser.eraseAll(_uid);
    expect((await user().collection('plans').get()).docs, isEmpty);
  });
}
