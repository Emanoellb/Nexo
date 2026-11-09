import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';
import 'nexo_filter_chip.dart';

/// `Chip/Assist` da lib (`d:mOwWD`): visual de 36 (`Shape/SM`, padding MD)
/// em SurfaceContainer, ícone de 16 em Icon/Default e rótulo LabelMedium em
/// OnSurface (ex.: "+ Adicionar tópico"). Alvo de 48 de altura.
class NexoAssistChip extends StatelessWidget {
  const NexoAssistChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final enabled = onPressed != null;
    final content = enabled ? c.onSurface : c.disabledContent;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      // Com a fonte ampliada, o rótulo quebra em linhas e o chip cresce na
      // altura, sem passar da largura disponível.
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: context.sizes.target),
        child: Center(
          widthFactor: 1,
          child: NexoTappable(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(context.shape.sm),
            color: enabled ? c.surfaceContainer : c.disabledBackground,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: NexoFilterChip.visualHeight,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.md,
                  vertical: spacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: enabled ? c.iconDefault : c.iconDisabled,
                    ),
                    SizedBox(width: spacing.sm),
                    Flexible(
                      child: Text(
                        label,
                        style: context
                            .textStyle(NexoTextStyles.labelMedium)
                            .copyWith(color: content),
                      ),
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
