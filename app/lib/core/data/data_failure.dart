/// Falha de leitura ou gravação nos repositórios de dados (Firestore),
/// independente do Firebase. Os repositórios lançam
/// [DataFailure] nos erros que a interface trata; o resto vira
/// [DataFailureCode.unknown].
enum DataFailureCode {
  /// Sem conexão (`unavailable` no Firestore).
  network,

  /// As regras recusaram (`permission-denied`).
  permissionDenied,
  unknown,
}

/// Código do Firestore (`FirebaseException.code`) → [DataFailureCode].
DataFailureCode dataFailureFromCode(String code) => switch (code) {
  'unavailable' => DataFailureCode.network,
  'permission-denied' => DataFailureCode.permissionDenied,
  _ => DataFailureCode.unknown,
};

class DataFailure implements Exception {
  const DataFailure(this.code);

  final DataFailureCode code;

  @override
  String toString() => 'DataFailure(${code.name})';
}
