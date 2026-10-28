import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_user.dart';

/// Leitura de `legalDocuments/current`: as versões vigentes dos Termos e da
/// Política, que o aceite precisa repetir (firestore-rules.md §4).
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
