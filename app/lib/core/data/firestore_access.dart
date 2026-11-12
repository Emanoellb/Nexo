import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/local_date.dart';
import 'data_failure.dart';
import 'firebase_ready.dart';

/// Acesso ao Firestore pelos repositórios reais:
/// - espera a carga do Firebase (feita na splash);
/// - converte as exceções do Firestore em [DataFailure].
///
/// Gravações, dois jeitos:
/// - [run] espera o servidor. Para o que precisa de internet e da resposta:
///   o Cadastro e a exclusão da conta.
/// - [send] não espera. O cache do aparelho aplica a mudança na hora, as
///   telas já a mostram e o Firestore manda quando houver conexão. Esperar o
///   servidor, sem internet, travaria a ação (e a fila do `ProgressActions`).
///   Se o servidor recusar depois, o Firestore desfaz a mudança no cache e o
///   erro é registrado ([FlutterError.reportError], que vai ao Crashlytics).
class FirestoreAccess {
  FirestoreAccess({required this.ready, FirebaseFirestore Function()? instance})
    : _instance = instance ?? (() => FirebaseFirestore.instance);

  /// Com um Firestore já pronto (nos testes, o em memória).
  FirestoreAccess.of(FirebaseFirestore db)
    : this(ready: Future<void>.value(), instance: () => db);

  /// A carga do Firebase (`Firebase.initializeApp`), feita na splash.
  final Future<void> ready;
  final FirebaseFirestore Function() _instance;

  static DataFailure _failure(FirebaseException e) =>
      DataFailure(dataFailureFromCode(e.code));

  /// Roda [action] e espera a resposta (leitura ou gravação confirmada).
  Future<T> run<T>(Future<T> Function(FirebaseFirestore db) action) async {
    await ready;
    try {
      return await action(_instance());
    } on FirebaseException catch (e) {
      throw _failure(e);
    }
  }

  /// Manda a gravação sem esperar o servidor (ver a classe). Erro ao montar
  /// a gravação (ex.: um campo inválido, sem login) chega a quem chamou,
  /// como nos fakes; só a resposta do servidor não é esperada.
  Future<void> send(Future<void> Function(FirebaseFirestore db) write) async {
    await ready;
    final db = _instance();
    unawaited(
      write(db).catchError((Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error is FirebaseException ? _failure(error) : error,
            stack: stack,
            library: 'nexo dados',
          ),
        );
      }),
    );
  }

  /// Escuta [open] (o cache primeiro, depois o servidor).
  Stream<T> watch<T>(Stream<T> Function(FirebaseFirestore db) open) async* {
    await ready;
    yield* open(_instance()).transform(
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, stack, sink) => sink.addError(
          error is FirebaseException ? _failure(error) : error,
          stack,
        ),
      ),
    );
  }

  /// Releitura do cache com o carimbo do servidor estimado (a hora do
  /// aparelho).
  static const _estimated = GetOptions(
    source: Source.cache,
    serverTimestampBehavior: ServerTimestampBehavior.estimate,
  );

  /// Escuta os documentos da consulta.
  ///
  /// Com gravação pendente, relê do cache com o carimbo estimado: o
  /// `snapshots()` do FlutterFire entrega `null` no lugar do carimbo até o
  /// servidor confirmar, e um dia finalizado sem internet pareceria aberto.
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> watchDocs(
    Query<Map<String, dynamic>> Function(FirebaseFirestore db) query,
  ) => watch((db) {
    final q = query(db);
    return q.snapshots().asyncMap((snapshot) async {
      if (!snapshot.metadata.hasPendingWrites) return snapshot.docs;
      try {
        return (await q.get(_estimated)).docs;
      } on FirebaseException {
        return snapshot.docs;
      }
    });
  });

  /// Escuta um documento, com o mesmo cuidado do [watchDocs].
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDoc(
    DocumentReference<Map<String, dynamic>> Function(FirebaseFirestore db) doc,
  ) => watch((db) {
    final ref = doc(db);
    return ref.snapshots().asyncMap((snapshot) async {
      if (!snapshot.metadata.hasPendingWrites) return snapshot;
      try {
        return await ref.get(_estimated);
      } on FirebaseException {
        return snapshot;
      }
    });
  });
}

/// Carimbos do servidor de um documento novo (`validCreate` das regras).
Map<String, Object> createdStamps() => {
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
};

/// Carimbo do servidor de uma alteração (`validUpdate` das regras).
Map<String, Object> updatedStamp() => {
  'updatedAt': FieldValue.serverTimestamp(),
};

/// `users/{uid}` do usuário logado, base dos repositórios de dados. Sem
/// [uid] (sem login ou sem verificar o e-mail), os repositórios devolvem
/// listas vazias e gravar é erro de programação.
class UserDocs {
  const UserDocs(this.uid);

  final String? uid;

  bool get signedIn => uid != null;

  DocumentReference<Map<String, dynamic>> user(FirebaseFirestore db) {
    final id = uid;
    if (id == null) throw StateError('Sem login: não há users/{uid}.');
    return db.collection('users').doc(id);
  }

  CollectionReference<Map<String, dynamic>> collection(
    FirebaseFirestore db,
    String name,
  ) => user(db).collection(name);
}

/// Apaga todos os documentos de [collection] em lotes de até [batchSize]
/// (limite do Firestore: 500 operações por lote). Lê do servidor: sem
/// internet falha (e quem chama retoma depois), em vez de apagar só o que o
/// aparelho conhece e deixar o resto para trás.
Future<void> deleteAllDocs(
  FirebaseFirestore db,
  Query<Map<String, dynamic>> collection, {
  int batchSize = 500,
}) async {
  while (true) {
    final page = await collection
        .limit(batchSize)
        .get(const GetOptions(source: Source.server));
    if (page.docs.isEmpty) return;
    final batch = db.batch();
    for (final doc in page.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    if (page.docs.length < batchSize) return;
  }
}

/// Inteiro de um campo do Firestore (no Android vem `int`; em outras
/// plataformas, `num`). `null` se não for número.
int? intField(Object? value) => value is num ? value.toInt() : null;

/// Data/hora de um carimbo; `null` se ausente ou pendente sem estimativa.
DateTime? timestampField(Object? value) =>
    value is Timestamp ? value.toDate() : null;

/// Data civil `AAAA-MM-DD`; `null` se ausente ou inválida.
LocalDate? localDateField(Object? value) {
  if (value is! String) return null;
  try {
    return LocalDate.parse(value);
  } on FormatException {
    return null;
  }
}

/// Ordem de criação pelo `createdAt`; sem carimbo (pendente) vai por último,
/// como o mais novo.
int compareByCreatedAt(
  DocumentSnapshot<Map<String, dynamic>> a,
  DocumentSnapshot<Map<String, dynamic>> b,
) {
  final ta = a.data()?['createdAt'];
  final tb = b.data()?['createdAt'];
  if (ta is! Timestamp) return tb is Timestamp ? 1 : 0;
  if (tb is! Timestamp) return -1;
  return ta.compareTo(tb);
}

/// O acesso ao Firestore do app (espera o [firebaseReadyProvider]).
final firestoreAccessProvider = Provider<FirestoreAccess>(
  (ref) => FirestoreAccess(ready: ref.watch(firebaseReadyProvider)),
);
