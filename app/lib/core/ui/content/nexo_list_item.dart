import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';

/// `Content/ListItem` da lib (`d:U3EjP`): ícone num quadro de 40
/// (SurfaceContainer, `Shape/SM`), título (BodyLarge), apoio (BodyMedium)
/// e o fim (chevron por padrão). Padding MD/LG, LG entre as partes. Sem
/// container próprio: vive num cartão com divisores.
///
/// [trailing] troca o chevron (ex.: X para remover, check na seleção);
/// `null` com [showChevron] falso deixa o fim vazio.
class NexoListItem extends StatelessWidget {
  const NexoListItem({
    super.key,
    required this.icon,
    required this.title,
    this.supporting,
    this.onTap,
    this.trailing,
    this.showChevron = true,
    this.selected,
    this.semanticsLabel,
  });

  final IconData icon;
  final String title;
  final String? supporting;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;

  /// Linha de seleção (ex.: "Ligar um plano"): anunciada como marcada ou
  /// não. `null`: não é seleção.
  final bool? selected;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final end =
        trailing ??
        (showChevron
            ? Icon(LucideIcons.chevronRight, size: 20, color: c.iconSecondary)
            : null);

    final row = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surfaceContainer,
                borderRadius: BorderRadius.circular(context.shape.sm),
              ),
              child: Icon(icon, size: 20, color: c.iconSecondary),
            ),
          ),
          SizedBox(width: spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyLarge!.copyWith(color: c.onSurface),
                ),
                if (supporting != null) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    supporting!,
                    style: textTheme.bodyMedium!.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (end != null) ...[SizedBox(width: spacing.md), end],
        ],
      ),
    );

    if (onTap == null) return row;
    return Semantics(
      button: selected == null,
      checked: selected,
      label: semanticsLabel ?? [title, ?supporting].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: row,
      ),
    );
  }
}

/// Última linha de um cartão de lista: "+ Adicionar …" em Primary, 56 de
/// altura (design de Disciplinas, Tópicos e Objetivos).
class NexoAddRow extends StatelessWidget {
  const NexoAddRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = LucideIcons.plus,
  });

  static const double height = 56;

  final String label;
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: height),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.lg),
            child: Row(
              children: [
                Icon(icon, size: 20, color: c.primary),
                SizedBox(width: spacing.md),
                Flexible(
                  child: Text(
                    label,
                    style: context
                        .textStyle(NexoTextStyles.labelMediumEmphasis)
                        .copyWith(color: c.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
