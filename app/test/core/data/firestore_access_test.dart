import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/data_failure.dart';
import 'package:nexo/core/data/firestore_access.dart';

FirebaseException _firestoreError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  test('códigos do Firestore viram DataFailure', () {
    expect(dataFailureFromCode('unavailable'), DataFailureCode.network);
    expect(
      dataFailureFromCode('permission-denied'),
      DataFailureCode.permissionDenied,
    );
    expect(dataFailureFromCode('not-found'), DataFailureCode.unknown);
  });

  group('FirestoreAccess', () {
    late FirestoreAccess access;

    setUp(() => access = FirestoreAccess.of(FakeFirebaseFirestore()));

    test('run converte o erro do Firestore', () async {
      await expectLater(
        access.run<void>((_) async => throw _firestoreError('unavailable')),
        throwsA(
          isA<DataFailure>().having(
            (f) => f.code,
            'code',
            DataFailureCode.network,
          ),
        ),
      );
    });

    test('watch converte o erro do Firestore', () async {
      await expectLater(
        access.watch<int>(
          (_) => Stream.error(_firestoreError('permission-denied')),
        ),
        emitsError(
          isA<DataFailure>().having(
            (f) => f.code,
            'code',
            DataFailureCode.permissionDenied,
          ),
        ),
      );
    });

    test('espera a carga do Firebase antes de usar o banco', () async {
      final ready = Completer<void>();
      var used = false;
      final waiting = FirestoreAccess(
        ready: ready.future,
        instance: () {
          used = true;
          return FakeFirebaseFirestore();
        },
      );
      final result = waiting.run((_) async => 1);
      await Future<void>.delayed(Duration.zero);
      expect(used, isFalse);
      ready.complete();
      expect(await result, 1);
      expect(used, isTrue);
    });

    test('send não espera o servidor e registra a recusa', () async {
      final reported = <Object>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) => reported.add(details.exception);
      addTearDown(() => FlutterError.onError = previous);

      final server = Completer<void>();
      // Volta antes de o "servidor" responder.
      await access.send((_) => server.future);
      expect(reported, isEmpty);

      server.completeError(_firestoreError('permission-denied'));
      await Future<void>.delayed(Duration.zero);
      expect(reported, [
        isA<DataFailure>().having(
          (f) => f.code,
          'code',
          DataFailureCode.permissionDenied,
        ),
      ]);
    });
  });
}
