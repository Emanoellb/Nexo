import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/data_failure.dart';
import 'package:nexo/core/data/firestore_access.dart';
import 'package:nexo/features/legal/data/firestore_legal_documents_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreLegalDocumentsRepository repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = FirestoreLegalDocumentsRepository(FirestoreAccess.of(db));
  });

  test('lê as versões vigentes de legalDocuments/current', () async {
    await db.collection('legalDocuments').doc('current').set({
      'termsVersion': 'terms-2026-11-01',
      'privacyVersion': 'privacy-2026-11-01',
    });
    final current = await repository.currentVersions();
    expect(current.termsVersion, 'terms-2026-11-01');
    expect(current.privacyVersion, 'privacy-2026-11-01');
  });

  test('sem o documento: DataFailure (o aceite seria recusado)', () async {
    await expectLater(
      repository.currentVersions(),
      throwsA(
        isA<DataFailure>().having(
          (f) => f.code,
          'code',
          DataFailureCode.unknown,
        ),
      ),
    );
  });

  test('faltando uma versão: null', () {
    expect(consentsFromFirestore({'termsVersion': 't1'}), isNull);
    expect(
      consentsFromFirestore({'termsVersion': '', 'privacyVersion': 'p1'}),
      isNull,
    );
    expect(consentsFromFirestore(null), isNull);
  });
}
