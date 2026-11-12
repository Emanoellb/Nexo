import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_access.dart';
import '../../auth/domain/auth_user.dart';
import 'firestore_legal_documents_repository.dart';

/// Leitura de `legalDocuments/current`: as versões vigentes dos Termos e da
/// Política, que o aceite precisa repetir (firestore-rules.md §4). Lança
/// `DataFailure` (core/data/data_failure.dart) quando não consegue ler.
abstract interface class LegalDocumentsRepository {
  Future<Consents> currentVersions();
}

final legalDocumentsRepositoryProvider = Provider<LegalDocumentsRepository>(
  (ref) =>
      FirestoreLegalDocumentsRepository(ref.watch(firestoreAccessProvider)),
);

/// Versões vigentes, lidas uma vez e guardadas enquanto alguém as usa (a
/// página dos Termos e da Política).
final currentLegalVersionsProvider = FutureProvider.autoDispose<Consents>(
  (ref) => ref.watch(legalDocumentsRepositoryProvider).currentVersions(),
);
