import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../domain/legal_markdown.dart';

/// O texto dos Termos e da Política, a partir dos blocos de
/// [parseLegalMarkdown], só com os tokens do design system:
/// - títulos (`##` TitleMedium, `###` TitleSmall), anunciados como título
///   pelo leitor de tela;
/// - parágrafos e listas em BodyMedium (OnSurface), negrito no peso
///   Emphasis da lib;
/// - tabelas como blocos empilhados ("coluna: valor"), que cabem no celular
///   e com fonte ampliada;
/// - notas em `Feedback/Alert` (Info).
class LegalText extends StatelessWidget {
  const LegalText({super.key, required this.blocks});

  final List<LegalBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final children = <Widget>[];
    LegalBlock? previous;
    for (final block in blocks) {
      if (children.isNotEmpty) {
        // Mais ar antes de um título; pouco entre itens da mesma lista.
        final gap = switch (block) {
          LegalHeading() => spacing.xl,
          LegalListItem() when previous is LegalListItem => spacing.xs,
          _ => spacing.md,
        };
        children.add(SizedBox(height: gap));
      }
      children.add(_block(context, block));
      previous = block;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _block(BuildContext context, LegalBlock block) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final body = textTheme.bodyMedium!.copyWith(color: c.onSurface);
    switch (block) {
      case LegalHeading(:final level, :final spans):
        return Semantics(
          header: true,
          child: Text.rich(
            _rich(
              spans,
              (level == 2 ? textTheme.titleMedium! : textTheme.titleSmall!)
                  .copyWith(color: c.onSurface),
            ),
          ),
        );
      case LegalParagraph(:final spans):
        return Text.rich(_rich(spans, body));
      case LegalListItem(:final spans, :final number, :final depth):
        return Padding(
          padding: EdgeInsetsDirectional.only(start: spacing.lg * depth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: spacing.xl,
                child: ExcludeSemantics(
                  child: Text(
                    number == null ? '•' : '$number.',
                    style: body.copyWith(color: c.onSurfaceVariant),
                  ),
                ),
              ),
              Expanded(child: Text.rich(_rich(spans, body))),
            ],
          ),
        );
      case LegalTable(:final headers, :final rows):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, row) in rows.indexed) ...[
              if (index > 0) SizedBox(height: spacing.sm),
              NexoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < row.length; i++) ...[
                      if (i > 0) SizedBox(height: spacing.sm),
                      if (i < headers.length)
                        Text.rich(
                          _rich(
                            headers[i],
                            context
                                .textStyle(NexoTextStyles.labelMediumEmphasis)
                                .copyWith(color: c.onSurfaceVariant),
                          ),
                        ),
                      Text.rich(_rich(row[i], body)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      case LegalNote(:final spans):
        return NexoAlert(
          tone: NexoAlertTone.info,
          icon: LucideIcons.info,
          message: spans.map((s) => s.text).join(),
        );
    }
  }

  TextSpan _rich(List<LegalSpan> spans, TextStyle base) => TextSpan(
    style: base,
    children: [
      for (final s in spans)
        TextSpan(
          text: s.text,
          // `Typography/Weight/Emphasis` (600), o peso de ênfase da lib.
          style: s.bold
              ? TextStyle(
                  fontWeight: NexoTextStyles.labelMediumEmphasis.fontWeight,
                )
              : null,
        ),
    ],
  );
}
