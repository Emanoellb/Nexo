import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/legal_markdown.dart';

/// Termos de Uso ou Política de Privacidade.
enum LegalDocument { terms, privacy }

/// De onde vem o texto dos Termos e da Política mostrado no app.
abstract interface class LegalTextSource {
  /// O Markdown do documento, ou `null` enquanto o texto final não está no
  /// app (a tela mostra só o título e a versão).
  Future<String?> load(LegalDocument document);
}

/// Os textos levados no próprio app (`app/assets/legal/`, declarados no
/// `pubspec.yaml`), para abrir sem internet (decisão do usuário,
/// 10/11/2026: leitor próprio, sem pacote). A sessão de dados e legal edita
/// esses arquivos.
///
/// **Texto e aceite andam juntos:** trocar o texto pede trocar
/// `legalDocuments/current` (`termsVersion`/`privacyVersion`) na mesma
/// versão do app, senão o aceite fica apontando para um texto que não é o
/// que a pessoa lê.
class AssetLegalTextSource implements LegalTextSource {
  const AssetLegalTextSource({this.paths = standardPaths});

  static const standardPaths = {
    LegalDocument.terms: 'assets/legal/termos-de-uso.md',
    LegalDocument.privacy: 'assets/legal/politica-de-privacidade.md',
  };

  final Map<LegalDocument, String> paths;

  @override
  Future<String?> load(LegalDocument document) async {
    final path = paths[document];
    return path == null ? null : rootBundle.loadString(path);
  }
}

final legalTextSourceProvider = Provider<LegalTextSource>(
  (ref) => const AssetLegalTextSource(),
);

/// Os blocos do documento, lidos uma vez enquanto a tela está aberta.
/// `null` = sem texto final no app.
final legalTextProvider = FutureProvider.autoDispose
    .family<List<LegalBlock>?, LegalDocument>((ref, document) async {
      final source = await ref.watch(legalTextSourceProvider).load(document);
      return source == null ? null : parseLegalMarkdown(source);
    });
