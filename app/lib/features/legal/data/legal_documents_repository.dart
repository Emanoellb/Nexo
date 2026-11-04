import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_user.dart';

/// Leitura de `legalDocuments/current`: as versões vigentes dos Termos e da
/// Política, que o aceite precisa repetir (firestore-rules.md §4). Lança
/// `DataFailure` (core/data/data_failure.dart) quando não consegue ler.
abstract interface class LegalDocumentsRepository {
  Future<Consents> currentVersions();
}

/// Versões fictícias da prototipação. A Política em rascunho vale a partir de
/// 01/11/2026 (docs/legal/politica-de-privacidade.md).
class FakeLegalDocumentsRepository implements LegalDocumentsRepository {
  const FakeLegalDocumentsRepository();

  static const current = Consents(
    termsVersion: 'terms-2026-11-01',
    privacyVersion: 'privacy-2026-11-01',
  );

  @override
  Future<Consents> currentVersions() async => current;
}

final legalDocumentsRepositoryProvider = Provider<LegalDocumentsRepository>(
  (ref) => const FakeLegalDocumentsRepository(),
);

/// Versões vigentes, lidas uma vez e guardadas enquanto alguém as usa (a
/// página dos Termos e da Política).
final currentLegalVersionsProvider = FutureProvider.autoDispose<Consents>(
  (ref) => ref.watch(legalDocumentsRepositoryProvider).currentVersions(),
);
