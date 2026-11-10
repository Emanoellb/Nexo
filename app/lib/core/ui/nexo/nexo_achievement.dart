import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';

/// `Nexo/Achievement` da lib: a medalha num círculo de 48 e o título
/// embaixo (LabelSmall, até 2 linhas).
/// - Conquistada: círculo `SecondaryContainer`, ícone em `Secondary`,
///   título em `OnSurface`.
/// - Bloqueada: círculo `SurfaceContainerHigh`, cadeado em `Icon/Disabled`,
///   título em `OnSurfaceVariant`.
///
/// O ícone e o cadeado mostram o estado (a cor não é o único sinal). Tocar
/// abre o detalhe.
class NexoAchievement extends StatelessWidget {
  const NexoAchievement({
    super.key,
    required this.title,
    required this.icon,
    required this.earned,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool earned;
  final VoidCallback? onTap;

  static const double circleSize = 48;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    return Semantics(
      button: true,
      label: '$title, ${earned ? 'conquistada' : 'bloqueada'}',
      onTap: onTap,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.shape.md),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: context.sizes.target),
          child: Padding(
            padding: EdgeInsets.all(spacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: earned
                        ? c.secondaryContainer
                        : c.surfaceContainerHigh,
                  ),
                  child: Icon(
                    earned ? icon : LucideIcons.lock,
                    size: 20,
                    color: earned ? c.secondary : c.iconDisabled,
                  ),
                ),
                SizedBox(height: spacing.sm),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: earned ? c.onSurface : c.onSurfaceVariant,
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
