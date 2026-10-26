import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';
import '../feedback/nexo_spinner.dart';
import '../foundation/nexo_tappable.dart';

/// `Actions/IconButton` da lib: alvo de 48 × 48, círculo, ícone Lucide.
///
/// Estados: Default, Pressed, Focused, Disabled (`onPressed == null`) e
/// Loading. [tooltip] é obrigatório: é o nome lido pelo leitor de tela.
class NexoIconButton extends StatelessWidget {
  const NexoIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 24,
    this.color,
    this.loading = false,
    this.focusNode,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double iconSize;

  /// Padrão: `Icon/Secondary`. A TopAppBar usa `Icon/Default`.
  final Color? color;
  final bool loading;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final enabled = onPressed != null;
    final interactive = enabled && !loading;
    final iconColor = enabled ? (color ?? c.iconSecondary) : c.iconDisabled;

    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: interactive,
        label: loading ? '$tooltip, carregando' : tooltip,
        onTap: interactive ? onPressed : null,
        excludeSemantics: true,
        child: NexoTappable(
          onTap: interactive ? onPressed : null,
          focusNode: focusNode,
          borderRadius: BorderRadius.circular(context.shape.full),
          color: enabled ? null : c.disabledBackground,
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: loading
                  ? NexoSpinner(color: iconColor, size: iconSize)
                  : Icon(icon, size: iconSize, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
