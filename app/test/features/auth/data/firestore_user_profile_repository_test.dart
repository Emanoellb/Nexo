import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/firestore_access.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/auth/data/firestore_user_profile_repository.dart';
import 'package:nexo/features/auth/domain/auth_user.dart';

import '../../../helpers/firestore_test_support.dart';

/// Campos das regras v0.9 (`app/firestore.rules`, `users/{uid}`).
const _createFields = {
  'displayName',
  'birthDate',
  'timeZone',
  'tutorialSeen',
  'overloadThreshold',
  'morningSummary',
  'points',
  'consents',
  'createdAt',
  'updatedAt',
};
const _requiredFields = {
  'displayName',
  'birthDate',
  'timeZone',
  'consents',
  'createdAt',
  'updatedAt',
};
const _editableFields = {
  'displayName',
  'timeZone',
  'tutorialSeen',
  'primaryPlanId',
  'overloadThreshold',
  'morningSummary',
  'points',
  'consents',
  'deletionRequestedAt',
  'createdAt',
  'updatedAt',
};

const _uid = 'u1';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreUserProfileRepository repository;

  DocumentReference<Map<String, dynamic>> doc() =>
      db.collection('users').doc(_uid);

  Future<Map<String, dynamic>> data() async => (await doc().get()).data()!;

  /// Um perfil já criado, com carimbos antigos (para ver o `updatedAt`
  /// mudar).
  Future<void> seed({int points = 10}) => doc().set({
    'displayName': 'Bia',
    'birthDate': '2000-05-20',
    'timeZone': 'America/Sao_Paulo',
    'tutorialSeen': false,
    'points': points,
    'consents': {
      'termsVersion': 't1',
      'privacyVersion': 'p1',
      'acceptedAt': oldStamp,
    },
    'createdAt': oldStamp,
    'updatedAt': oldStamp,
  });

  /// Roda [change] e confere que só mexeu em campos editáveis, sem trocar o
  /// `createdAt` e renovando o `updatedAt` (validUpdate das regras).
  Future<Set<String>> expectValidUpdate(Future<void> Function() change) async {
    final before = await agedData(doc());
    await change();
    await settle();
    final after = await data();
    final changed = changedKeys(before, after);
    expect(changed.difference(_editableFields), isEmpty);
    expect(changed, isNot(contains('createdAt')));
    expect(changed, contains('updatedAt'));
    expect(after['updatedAt'], isA<Timestamp>());
    return changed;
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = FirestoreUserProfileRepository(FirestoreAccess.of(db));
  });

  group('createProfile', () {
    test('grava só os campos de criação das regras, com o aceite', () async {
      await repository.createProfile(
        _uid,
        NewUserProfile(
          displayName: '  Bia  ',
          birthDate: const LocalDate(2000, 5, 20),
          timeZone: 'America/Sao_Paulo',
          consents: const Consents(termsVersion: 't1', privacyVersion: 'p1'),
          today: const LocalDate(2026, 11, 11),
        ),
      );
      final saved = await data();
      expect(_createFields.containsAll(saved.keys), isTrue);
      expect(saved.keys.toSet().containsAll(_requiredFields), isTrue);
      expect(saved['displayName'], 'Bia');
      expect(saved['birthDate'], '2000-05-20');
      expect(saved['timeZone'], 'America/Sao_Paulo');
      expect(saved['tutorialSeen'], isFalse);
      expect(saved['points'], 0);
      expect(saved['createdAt'], isA<Timestamp>());
      expect(saved['updatedAt'], isA<Timestamp>());
      final consents = saved['consents'] as Map<String, dynamic>;
      expect(consents.keys.toSet(), {
        'termsVersion',
        'privacyVersion',
        'acceptedAt',
      });
      expect(consents['termsVersion'], 't1');
      expect(consents['privacyVersion'], 'p1');
      expect(consents['acceptedAt'], isA<Timestamp>());
    });
  });

  group('watchProfile', () {
    test('sem documento: null; depois, o perfil e cada mudança', () async {
      final seen = <UserProfile?>[];
      final sub = repository.watchProfile(_uid).listen(seen.add);
      addTearDown(sub.cancel);
      await settle();
      expect(seen, [null]);

      await seed();
      await settle();
      expect(seen.last?.displayName, 'Bia');
      expect(seen.last?.birthDate, const LocalDate(2000, 5, 20));
      expect(seen.last?.points, 10);
      expect(
        seen.last?.overloadThreshold,
        UserProfile.defaultOverloadThreshold,
      );
      expect(seen.last?.morningSummary, MorningSummary.standard);

      await repository.markTutorialSeen(_uid);
      await settle();
      expect(seen.last?.tutorialSeen, isTrue);
    });
  });

  group('ajustes do dia a dia', () {
    setUp(seed);

    test('tutorial visto', () async {
      final changed = await expectValidUpdate(
        () => repository.markTutorialSeen(_uid),
      );
      expect(changed, {'tutorialSeen', 'updatedAt'});
      expect((await data())['tutorialSeen'], isTrue);
    });

    test('pontos: soma e subtrai', () async {
      await expectValidUpdate(() => repository.addPoints(_uid, 5));
      expect((await data())['points'], 15);
      await expectValidUpdate(() => repository.addPoints(_uid, -3));
      expect((await data())['points'], 12);
    });

    test('pontos: não passa de 0 nem do máximo das regras', () async {
      await repository.addPoints(_uid, -50);
      await settle();
      expect((await data())['points'], 0);

      await doc().update({'points': UserProfile.maxPoints - 1});
      await repository.addPoints(_uid, 5);
      await settle();
      expect((await data())['points'], UserProfile.maxPoints);
    });

    test('pontos: sem mudança, nada é gravado', () async {
      await doc().update({'points': 0});
      await repository.addPoints(_uid, 0);
      await repository.addPoints(_uid, -1);
      await settle();
      expect((await data())['updatedAt'], oldStamp);
    });

    test('plano principal: grava e limpa', () async {
      await expectValidUpdate(() => repository.setPrimaryPlan(_uid, 'p1'));
      expect((await data())['primaryPlanId'], 'p1');
      await expectValidUpdate(() => repository.setPrimaryPlan(_uid, null));
      expect((await data())['primaryPlanId'], isNull);
    });

    test('nome (sem espaços nas pontas), limite e aviso da manhã', () async {
      await expectValidUpdate(
        () => repository.updateDisplayName(_uid, ' Ana '),
      );
      await expectValidUpdate(() => repository.setOverloadThreshold(_uid, 8));
      await expectValidUpdate(
        () => repository.setMorningSummary(
          _uid,
          const MorningSummary(enabled: false, time: '07:30'),
        ),
      );
      final saved = await data();
      expect(saved['displayName'], 'Ana');
      expect(saved['overloadThreshold'], 8);
      expect(saved['morningSummary'], {'enabled': false, 'time': '07:30'});
      expect(saved['birthDate'], '2000-05-20');
    });
  });

  group('exclusão da conta', () {
    setUp(seed);

    test('marca uma vez só, com o carimbo do servidor', () async {
      final changed = await expectValidUpdate(
        () => repository.markDeletionRequested(_uid),
      );
      expect(changed, {'deletionRequestedAt', 'updatedAt'});
      final first = (await data())['deletionRequestedAt'];
      expect(first, isA<Timestamp>());

      await repository.markDeletionRequested(_uid);
      expect((await data())['deletionRequestedAt'], first);
    });

    test('apaga o documento', () async {
      await repository.markDeletionRequested(_uid);
      await repository.deleteProfile(_uid);
      expect((await doc().get()).exists, isFalse);
    });
  });

  group('userProfileFromFirestore', () {
    test('campos ausentes ou de outro tipo viram o padrão', () {
      final profile = userProfileFromFirestore({
        'displayName': 3,
        'points': 'muitos',
        'overloadThreshold': 99,
        'morningSummary': {'enabled': 'sim'},
        'birthDate': '2000-02-30',
        'primaryPlanId': 7,
      })!;
      expect(profile.displayName, '');
      expect(profile.points, 0);
      expect(profile.overloadThreshold, UserProfile.maxOverloadThreshold);
      expect(profile.morningSummary, MorningSummary.standard);
      expect(profile.birthDate, isNull);
      expect(profile.primaryPlanId, isNull);
      expect(profile.deletionRequestedAt, isNull);
    });

    test('deletionRequestedAt gravado', () {
      final at = DateTime.utc(2026, 11, 10, 12);
      final profile = userProfileFromFirestore({
        'displayName': 'Bia',
        'deletionRequestedAt': Timestamp.fromDate(at),
      })!;
      expect(profile.deletionRequestedAt?.toUtc(), at);
    });
  });
}
