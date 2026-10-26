import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/nexo_theme.dart';
import '../feedback/nexo_spinner.dart';
import '../foundation/nexo_tappable.dart';

enum NexoButtonVariant { primary, secondary, tertiary }

/// `Actions/Button/Primary | Secondary | Tertiary` da lib.
///
/// Estados: Default, Pressed, Focused, Disabled (`onPressed == null`) e
/// Loading (`loading: true`: rótulo some, spinner no centro, sem toque).
/// Altura mínima de 48 px, que cresce com a fonte ampliada.
class NexoButton extends StatelessWidget {
  const NexoButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.focusNode,
  }) : variant = NexoButtonVariant.primary,
       contentColor = null,
       compact = false;

  const NexoButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.focusNode,
  }) : variant = NexoButtonVariant.secondary,
       contentColor = null,
       compact = false;

  /// [contentColor] troca a cor do rótulo, como na ação de um Alert
  /// (`On<Tom>Container`). [compact] tira o padding lateral.
  const NexoButton.tertiary({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.contentColor,
    this.compact = false,
    this.focusNode,
  }) : variant = NexoButtonVariant.tertiary;

  final String label;
  final VoidCallback? onPressed;
  final NexoButtonVariant variant;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool loading;

  /// Ocupa toda a largura disponível (Full Width na lib).
  final bool expand;
  final Color? contentColor;
  final bool compact;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final enabled = onPressed != null;

    Color? background;
    var side = BorderSide.none;
    Color foreground;
    Color iconColor;

    if (!enabled) {
      background = variant == NexoButtonVariant.tertiary
          ? null
          : c.disabledBackground;
      foreground = c.disabledContent;
      iconColor = c.iconDisabled;
    } else {
      switch (variant) {
        case NexoButtonVariant.primary:
          background = c.primary;
          foreground = c.onPrimary;
          iconColor = c.onPrimary;
        case NexoButtonVariant.secondary:
          background = c.surfaceContainerLowest;
          side = BorderSide(color: c.outline);
          foreground = c.onSurface;
          iconColor = c.iconDefault;
        case NexoButtonVariant.tertiary:
          foreground = contentColor ?? c.primary;
          iconColor = foreground;
      }
    }

    return NexoButtonShell(
      label: label,
      onPressed: onPressed,
      loading: loading,
      expand: expand,
      background: background,
      side: side,
      foreground: foreground,
      spinnerColor: iconColor,
      horizontalPadding: compact ? 0 : null,
      focusNode: focusNode,
      leading: leadingIcon == null
          ? null
          : Icon(leadingIcon, size: 20, color: iconColor),
      trailing: trailingIcon == null
          ? null
          : Icon(trailingIcon, size: 20, color: iconColor),
    );
  }
}

/// `Actions/Button/Social/Google` da lib. Login social do MVP (sem Apple).
class NexoGoogleButton extends StatelessWidget {
  const NexoGoogleButton({
    super.key,
    required this.onPressed,
    this.label = 'Continuar com o Google',
    this.loading = false,
    this.expand = true,
    this.focusNode,
  });

  static const String _markAsset = 'assets/icons/google-g.svg';

  final VoidCallback? onPressed;
  final String label;
  final bool loading;
  final bool expand;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final enabled = onPressed != null;

    return NexoButtonShell(
      focusNode: focusNode,
      label: label,
      onPressed: onPressed,
      loading: loading,
      expand: expand,
      background: enabled ? c.surfaceContainerLowest : c.disabledBackground,
      side: enabled ? BorderSide(color: c.controlBorder) : BorderSide.none,
      foreground: enabled ? c.onSurface : c.disabledContent,
      spinnerColor: c.onSurface,
      leading: Opacity(
        opacity: enabled ? 1 : 0.38,
        child: SvgPicture.asset(
          _markAsset,
          width: 20,
          height: 20,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

/// Moldura comum aos botões com rótulo. Use [NexoButton] ou
/// [NexoGoogleButton]; esta classe é pública só para os testes.
class NexoButtonShell extends StatelessWidget {
  const NexoButtonShell({
    super.key,
    required this.label,
    required this.onPressed,
    required this.loading,
    required this.expand,
    required this.background,
    required this.side,
    required this.foreground,
    required this.spinnerColor,
    this.leading,
    this.trailing,
    this.horizontalPadding,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  final Color? background;
  final BorderSide side;
  final Color foreground;
  final Color spinnerColor;
  final Widget? leading;
  final Widget? trailing;
  final double? horizontalPadding;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final interactive = onPressed != null && !loading;
    final style = Theme.of(context).textTheme.labelLarge!
        .copyWith(color: foreground);

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, SizedBox(width: spacing.sm)],
        Flexible(
          child: Text(
            label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        if (trailing != null) ...[SizedBox(width: spacing.sm), trailing!],
      ],
    );

    final button = Semantics(
      button: true,
      enabled: interactive,
      label: loading ? '$label, carregando' : label,
      onTap: interactive ? onPressed : null,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: interactive ? onPressed : null,
        focusNode: focusNode,
        borderRadius: BorderRadius.circular(context.shape.md),
        color: background,
        side: side,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding ?? spacing.lg,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(opacity: loading ? 0 : 1, child: content),
                if (loading) NexoSpinner(color: spinnerColor),
              ],
            ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
