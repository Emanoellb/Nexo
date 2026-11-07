import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';

/// `Chip/Filter` da lib: visual de 36 (`Shape/SM`, padding MD) em
/// SurfaceContainer, rótulo OnSurfaceVariant. Selecionado: check +
/// PrimaryContainer + OnPrimaryContainer (estado por check e fundo, não só
/// cor). Alvo de toque `Size/Target` (48; a lib desenha 44). Escolha única
/// (chips de disciplina): anunciado como grupo exclusivo.
class NexoFilterChip extends StatelessWidget {
  const NexoFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  static const double visualHeight = 36;

  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final radius = BorderRadius.circular(context.shape.sm);
    final enabled = onSelected != null;
    final Color content = !enabled
        ? c.disabledContent
        : selected
        ? c.onPrimaryContainer
        : c.onSurfaceVariant;
    final Color background = !enabled
        ? c.disabledBackground
        : selected
        ? c.primaryContainer
        : c.surfaceContainer;

    return Semantics(
      button: true,
      selected: selected,
      // Escolha única: o leitor de tela anuncia como grupo (como o
      // SegmentedButton do Flutter).
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      label: label,
      onTap: onSelected,
      excludeSemantics: true,
      child: SizedBox(
        height: context.sizes.target,
        child: Center(
          child: NexoTappable(
            onTap: onSelected,
            borderRadius: radius,
            color: background,
            child: SizedBox(
              height: visualHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      Icon(LucideIcons.check, size: 16, color: content),
                      SizedBox(width: spacing.sm),
                    ],
                    Text(
                      label,
                      maxLines: 1,
                      style: context
                          .textStyle(NexoTextStyles.labelMedium)
                          .copyWith(color: content),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
