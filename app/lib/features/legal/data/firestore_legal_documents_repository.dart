import '../../../core/data/data_failure.dart';
import '../../../core/data/firestore_access.dart';
import '../../auth/domain/auth_user.dart';
import 'legal_documents_repository.dart';

/// `legalDocuments/current` no Firestore: as versões vigentes, escritas pelo
/// console (firebase-setup.md §7). Leitura pública, então vale antes de a
/// conta existir (Cadastro). Sem internet, o cache do aparelho, se houver.
class FirestoreLegalDocumentsRepository implements LegalDocumentsRepository {
  FirestoreLegalDocumentsRepository(this._access);

  final FirestoreAccess _access;

  @override
  Future<Consents> currentVersions() => _access.run((db) async {
    final snapshot = await db.collection('legalDocuments').doc('current').get();
    final consents = consentsFromFirestore(snapshot.data());
    // Sem o documento (ou com outro formato), o aceite seria recusado.
    if (consents == null) throw const DataFailure(DataFailureCode.unknown);
    return consents;
  });
}

/// `{termsVersion, privacyVersion}` → [Consents]; `null` se faltar um dos
/// dois.
Consents? consentsFromFirestore(Map<String, dynamic>? data) {
  final terms = data?['termsVersion'];
  final privacy = data?['privacyVersion'];
  if (terms is! String || terms.isEmpty) return null;
  if (privacy is! String || privacy.isEmpty) return null;
  return Consents(termsVersion: terms, privacyVersion: privacy);
}
