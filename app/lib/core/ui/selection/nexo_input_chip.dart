import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';

/// `Chip/Input` da lib (`d:oEHYi`): visual de 36 (`Shape/SM`, padding MD)
/// em SurfaceContainer, rótulo LabelMedium em OnSurface e o X de 16 em
/// Icon/Secondary. O X é o alvo, com `Size/Target` (48) e o nome
/// [removeLabel] (ex.: "Remover aviso de 1 dia").
class NexoInputChip extends StatelessWidget {
  const NexoInputChip({
    super.key,
    required this.label,
    required this.removeLabel,
    required this.onRemove,
  });

  static const double visualHeight = 36;

  final String label;
  final String removeLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final target = context.sizes.target;
    final radius = BorderRadius.circular(context.shape.sm);

    // O alvo de 48 é a área do X; o visual de 36 fica centrado nela.
    return SizedBox(
      height: target,
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          Positioned.fill(
            top: (target - visualHeight) / 2,
            bottom: (target - visualHeight) / 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surfaceContainer,
                borderRadius: radius,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: spacing.md),
              Text(
                label,
                maxLines: 1,
                style: context
                    .textStyle(NexoTextStyles.labelMedium)
                    .copyWith(color: c.onSurface),
              ),
              Semantics(
                button: true,
                label: removeLabel,
                onTap: onRemove,
                excludeSemantics: true,
                child: NexoTappable(
                  onTap: onRemove,
                  borderRadius: radius,
                  child: SizedBox(
                    width: target,
                    height: target,
                    child: Icon(
                      LucideIcons.x,
                      size: 16,
                      color: c.iconSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
