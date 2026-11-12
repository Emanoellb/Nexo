import 'package:nexo/features/auth/domain/auth_user.dart';
import 'package:nexo/features/legal/data/legal_documents_repository.dart';

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
