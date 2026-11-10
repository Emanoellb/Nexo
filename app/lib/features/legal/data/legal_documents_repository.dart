import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_user.dart';

/// Leitura de `legalDocuments/current`: as versões vigentes dos Termos e da
/// Política, que o aceite precisa repetir (firestore-rules.md §4). Lança
/// `DataFailure` (core/data/data_failure.dart) quando não consegue ler.
abstract interface class LegalDocumentsRepository {
  Future<Consents> currentVersions();
}

/// Versões técnicas da prototipação, só para o cadastro funcionar nos testes
/// (o texto lido no app fica em `app/assets/legal/`; a vigência ainda está a
/// definir). Trocar o texto pede trocar estas versões na mesma versão do
/// app.
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
