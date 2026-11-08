import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';

/// `Selection/Switch` da lib (`d:QQfAC`): trilho de 44 × 24 (`Shape/Full`)
/// num alvo de 48, com rótulo (LabelMedium) e ajuda (LabelSmall) ao lado.
/// Desligado: trilho SurfaceContainerHigh com borda Control/Border e bolinha
/// OnSurfaceVariant à esquerda. Ligado: trilho Primary e bolinha OnPrimary à
/// direita (posição e cor; a cor não é o único sinal). A linha inteira é o
/// alvo.
class NexoSwitch extends StatelessWidget {
  const NexoSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final enabled = onChanged != null;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : context.motion.short;
    final track = !enabled
        ? c.disabledBackground
        : value
        ? c.primary
        : c.surfaceContainerHigh;
    final thumb = !enabled
        ? c.disabledContent
        : value
        ? c.onPrimary
        : c.onSurfaceVariant;

    void toggle() => onChanged?.call(!value);

    return Semantics(
      toggled: value,
      enabled: enabled,
      label: label,
      hint: helper,
      onTap: enabled ? toggle : null,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: enabled ? toggle : null,
        borderRadius: BorderRadius.circular(context.shape.md),
        child: Row(
          children: [
            SizedBox.square(
              dimension: context.sizes.target,
              child: Center(
                child: AnimatedContainer(
                  duration: duration,
                  width: 44,
                  height: 24,
                  padding: EdgeInsets.symmetric(horizontal: spacing.xs),
                  alignment: value
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  decoration: BoxDecoration(
                    color: track,
                    borderRadius: BorderRadius.circular(context.shape.full),
                    border: value && enabled
                        ? null
                        : Border.all(color: c.controlBorder),
                  ),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: thumb,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.labelMedium!.copyWith(
                      color: enabled ? c.onSurface : c.disabledContent,
                    ),
                  ),
                  if (helper != null) ...[
                    SizedBox(height: spacing.xs),
                    Text(
                      helper!,
                      style: textTheme.labelSmall!.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
