import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';

/// Superfície tocável com os estados de interação da lib:
/// - Pressed: sobrepõe `Colors/Semantic/Pressed` ao fundo;
/// - Focused: contorno de 2 px em `Colors/Semantic/Focus`, só na navegação
///   por teclado ou controle (modo de destaque "traditional").
///
/// Não define semântica: quem usa decide o papel (botão, checkbox…).
class NexoTappable extends StatefulWidget {
  const NexoTappable({
    super.key,
    required this.child,
    required this.onTap,
    required this.borderRadius,
    this.color,
    this.side = BorderSide.none,
    this.focusRingOutside = true,
    this.focusNode,
    this.autofocus = false,
  });

  final Widget child;

  /// `null` deixa a superfície inerte (sem toque e sem foco).
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color? color;
  final BorderSide side;

  /// Botões usam o anel por fora; o indicador de páginas, por dentro.
  final bool focusRingOutside;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<NexoTappable> createState() => _NexoTappableState();
}

class _NexoTappableState extends State<NexoTappable> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    super.dispose();
  }

  void _onHighlightMode(FocusHighlightMode _) {
    if (_focused) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nexoColors;
    final showRing =
        _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final shape = RoundedRectangleBorder(
      borderRadius: widget.borderRadius,
      side: widget.side,
    );

    return Container(
      foregroundDecoration: showRing
          ? BoxDecoration(
              borderRadius: widget.borderRadius,
              border: Border.all(
                color: colors.focus,
                width: 2,
                strokeAlign: widget.focusRingOutside
                    ? BorderSide.strokeAlignOutside
                    : BorderSide.strokeAlignInside,
              ),
            )
          : null,
      child: Material(
        // Sem cor própria: superfície invisível, só para a tinta do toque.
        type: widget.color == null
            ? MaterialType.transparency
            : MaterialType.canvas,
        color: widget.color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          customBorder: shape,
          splashFactory: NoSplash.splashFactory,
          onFocusChange: (value) => setState(() => _focused = value),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return colors.pressed;
            if (states.contains(WidgetState.hovered)) return colors.hover;
            // Sem camada nos outros estados (o foco é o anel, não um véu).
            return colors.hover.withValues(alpha: 0);
          }),
          child: widget.child,
        ),
      ),
    );
  }
}
