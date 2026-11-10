import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../data/legal_documents_repository.dart';
import '../data/legal_texts.dart';
import 'legal_text.dart';

export '../data/legal_texts.dart' show LegalDocument;

/// Termos de Uso ou Política de Privacidade, abertos pelos links do aceite
/// e pelo Perfil.
///
/// Mostra o texto ([LegalText]) de `app/assets/legal/`, com a versão do
/// próprio documento ("Versão 0.3 · Vigência: a definir"). O id técnico
/// (`terms-2026-11-01`) fica só para o aceite, nos bastidores (decisão do
/// usuário, 10/11/2026). Sem texto (não deveria acontecer), mostra o id.
class LegalDocumentPage extends ConsumerWidget {
  const LegalDocumentPage({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final versions = ref.watch(currentLegalVersionsProvider);
    final text = ref.watch(legalTextProvider(document)).value;
    final title = switch (document) {
      LegalDocument.terms => 'Termos de Uso',
      LegalDocument.privacy => 'Política de Privacidade',
    };

    return Scaffold(
      backgroundColor: c.surface,
      appBar: NexoTopAppBar(title: title, onBack: () => context.pop()),
      body: ListView(
        padding: EdgeInsets.all(spacing.lg),
        children: [
          // Sem texto: o id técnico, como antes. Com texto, a versão é a do
          // próprio documento (a primeira linha dele).
          // A leitura fica no provider, fora do build (achado [12]).
          if (text == null)
            switch (versions) {
              AsyncData(:final value) => Text(
                'Versão vigente: ${switch (document) {
                  LegalDocument.terms => value.termsVersion,
                  LegalDocument.privacy => value.privacyVersion,
                }}',
                style: textTheme.labelMedium!.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
              AsyncError() => NexoAlert(
                tone: NexoAlertTone.error,
                message:
                    'Não conseguimos carregar a versão agora. Tente de novo em '
                    'instantes.',
                actionLabel: 'Tentar de novo',
                onAction: () => ref.invalidate(currentLegalVersionsProvider),
              ),
              _ => const SizedBox.shrink(),
            },
          SizedBox(height: spacing.md),
          if (text == null)
            Text(
              'O texto completo aparece aqui quando o documento for '
              'publicado.',
              style: textTheme.bodyLarge!.copyWith(color: c.onSurface),
            )
          else
            LegalText(blocks: text),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}
