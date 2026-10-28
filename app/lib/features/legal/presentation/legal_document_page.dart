import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../data/legal_documents_repository.dart';

enum LegalDocument { terms, privacy }

/// Termos de Uso ou Política de Privacidade, abertos pelos links do aceite.
///
/// Na prototipação mostra só o título e a versão vigente: os textos em
/// docs/legal/ ainda são rascunhos e não vão para o app.
class LegalDocumentPage extends ConsumerWidget {
  const LegalDocumentPage({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final title = switch (document) {
      LegalDocument.terms => 'Termos de Uso',
      LegalDocument.privacy => 'Política de Privacidade',
    };

    return Scaffold(
      backgroundColor: c.surface,
      appBar: NexoTopAppBar(title: title, onBack: () => context.pop()),
      body: FutureBuilder(
        future: ref.read(legalDocumentsRepositoryProvider).currentVersions(),
        builder: (context, snapshot) {
          final versions = snapshot.data;
          final version = versions == null
              ? null
              : switch (document) {
                  LegalDocument.terms => versions.termsVersion,
                  LegalDocument.privacy => versions.privacyVersion,
                };
          return ListView(
            padding: EdgeInsets.all(spacing.lg),
            children: [
              if (version != null)
                Text(
                  'Versão vigente: $version',
                  style: textTheme.labelMedium!.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              SizedBox(height: spacing.md),
              Text(
                'O texto completo aparece aqui quando o documento for '
                'publicado.',
                style: textTheme.bodyLarge!.copyWith(color: c.onSurface),
              ),
            ],
          );
        },
      ),
    );
  }
}
