import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';

/// Cabeçalho recolhível de uma seção (Tarefas, Planos, Objetivos) (ListHeader com o chevron no lugar da
/// ação; design de Tarefas, 04/11/2026): o cabeçalho inteiro é o alvo;
/// chevron para cima aberto, para baixo recolhido.
class NexoSectionHeader extends StatelessWidget {
  const NexoSectionHeader({
    super.key,
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      header: true,
      expanded: expanded,
      label: '$title, $count',
      onTap: onToggle,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(context.shape.md),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: context.sizes.target),
          child: Padding(
            // Como o ListHeader: LG no começo; o chevron encosta no fim
            // (alinhado à borda do cartão, design de Tarefas 03).
            padding: EdgeInsetsDirectional.only(start: spacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: spacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium!.copyWith(
                          color: c.onSurface,
                        ),
                      ),
                      Text(
                        '$count',
                        style: textTheme.labelSmall!.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 20,
                  color: c.iconSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
