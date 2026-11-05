import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';

/// `Actions/FAB` da lib: botão circular de 64 px em Primary, com o ícone
/// "+", Elevation/3 e nome acessível "Criar".
class NexoFab extends StatelessWidget {
  const NexoFab({
    super.key,
    required this.onPressed,
    this.icon = LucideIcons.plus,
    this.label = 'Criar',
  });

  static const double size = 64;

  final VoidCallback? onPressed;
  final IconData icon;

  /// Nome lido pelo leitor de tela.
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final radius = BorderRadius.circular(context.shape.full);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: context.elevation.level(3),
          ),
          child: NexoTappable(
            onTap: onPressed,
            borderRadius: radius,
            color: enabled ? c.primary : c.disabledBackground,
            child: SizedBox.square(
              dimension: size,
              child: Icon(
                icon,
                size: 24,
                color: enabled ? c.onPrimary : c.iconDisabled,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
