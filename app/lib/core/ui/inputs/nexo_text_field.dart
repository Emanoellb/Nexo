import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../buttons/nexo_icon_button.dart';

/// `Input/TextField` da lib: rótulo ACIMA do campo (não flutuante), campo de
/// 48 px e texto de apoio abaixo.
///
/// Estados: Default, Focused (borda Primary 2 px), Filled, Disabled,
/// Error ([errorText] preenchido: borda Error 2 px e texto de erro; o ícone
/// de erro só aparece em campo sem ação própria) e ReadOnly (fundo
/// SurfaceContainer, cadeado).
class NexoTextField extends StatefulWidget {
  const NexoTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hintText,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.readOnly = false,
    this.obscurable = false,
    this.leadingIcon,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.autocorrect = true,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;

  /// Texto de apoio fixo (ex.: a regra de senha). Some quando há erro.
  final String? helperText;

  /// Mensagem de erro. Quando não é nula, o campo entra no estado Error.
  final String? errorText;
  final bool enabled;
  final bool readOnly;

  /// Campo de senha: esconde o texto e mostra o botão de exibir/ocultar.
  final bool obscurable;
  final IconData? leadingIcon;

  /// Ação no fim do campo (ex.: o calendário do [NexoDateField]), num alvo
  /// de 48 px. Dá lugar ao ícone de erro e ao cadeado.
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;

  @override
  State<NexoTextField> createState() => _NexoTextFieldState();
}

class _NexoTextFieldState extends State<NexoTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(context.shape.md);

    // Controle da lib (`Input/TextField` › Control) com a altura do alvo.
    final controlHeight = context.sizes.target;
    final valueStyle = textTheme.bodyMedium!;
    final valueLineHeight = valueStyle.fontSize! * valueStyle.height!;

    final hasError = widget.errorText != null;
    final disabled = !widget.enabled;
    final readOnly = widget.readOnly && !disabled;

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color, width: width),
    );

    final restingBorder = hasError
        ? border(c.error, 2)
        : border(readOnly ? c.outlineVariant : c.controlBorder, 1);
    final focusedBorder = hasError
        ? border(c.error, 2)
        : border(readOnly ? c.outlineVariant : c.primary, 2);

    final Color fill = disabled
        ? c.disabledBackground
        : readOnly
        ? c.surfaceContainer
        : c.surfaceContainerLowest;
    final Color valueColor = disabled ? c.disabledContent : c.onSurface;
    final Color supportColor = disabled
        ? c.disabledContent
        : hasError
        ? c.error
        : c.onSurfaceVariant;

    // Campo com ação própria (olho da senha, calendário) mantém a ação no
    // erro: o erro fica na borda e no texto (pedido do usuário, 27/10/2026).
    // Sem ação própria, o erro ganha o ícone.
    final suffixIsButton =
        !readOnly && (widget.obscurable || widget.trailing != null);
    Widget? suffix;
    if (suffixIsButton && widget.obscurable) {
      suffix = NexoIconButton(
        icon: _obscured ? LucideIcons.eye : LucideIcons.eyeOff,
        tooltip: _obscured ? 'Mostrar senha' : 'Ocultar senha',
        iconSize: 20,
        onPressed: disabled
            ? null
            : () => setState(() => _obscured = !_obscured),
      );
    } else if (suffixIsButton) {
      suffix = widget.trailing;
    } else if (hasError) {
      suffix = Icon(LucideIcons.circleAlert, size: 20, color: c.iconError);
    } else if (readOnly) {
      suffix = Icon(LucideIcons.lockKeyhole, size: 20, color: c.iconSecondary);
    }

    final supportText = widget.errorText ?? widget.helperText;

    // O rótulo visível fica fora da árvore de acessibilidade e entra como
    // nome do próprio campo. O botão "Mostrar senha" segue como nó separado.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            widget.label,
            style: textTheme.labelMedium!.copyWith(
              color: disabled ? c.disabledContent : c.onSurface,
            ),
          ),
        ),
        // Na lib: XS embaixo da região do rótulo + XS de gap = SM.
        SizedBox(height: spacing.sm),
        Semantics(
          label: widget.label,
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            obscureText: widget.obscurable && _obscured,
            enableSuggestions: !widget.obscurable,
            autocorrect: widget.obscurable ? false : widget.autocorrect,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            autofillHints: widget.autofillHints,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onEditingComplete: widget.onEditingComplete,
            style: valueStyle.copyWith(color: valueColor),
            cursorColor: c.primary,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: fill,
              hintText: widget.hintText,
              hintStyle: textTheme.bodyMedium!.copyWith(
                color: disabled ? c.disabledContent : c.onSurfaceVariant,
              ),
              constraints: BoxConstraints(minHeight: controlHeight),
              // Texto centrado no controle de 48 (lib: altura fixa, sem
              // padding vertical): sobra dividida entre cima e baixo.
              contentPadding: EdgeInsets.symmetric(
                horizontal: spacing.lg,
                vertical: (controlHeight - valueLineHeight) / 2,
              ),
              prefixIcon: widget.leadingIcon == null
                  ? null
                  : Padding(
                      padding: EdgeInsets.only(
                        left: spacing.lg,
                        right: spacing.sm,
                      ),
                      child: Icon(
                        widget.leadingIcon,
                        size: 20,
                        color: disabled ? c.iconDisabled : c.iconSecondary,
                      ),
                    ),
              prefixIconConstraints: const BoxConstraints(),
              suffixIcon: suffix == null
                  ? null
                  : Padding(
                      padding: EdgeInsets.only(
                        right: suffixIsButton ? 0 : spacing.lg,
                      ),
                      child: suffix,
                    ),
              suffixIconConstraints: const BoxConstraints(),
              enabledBorder: restingBorder,
              focusedBorder: focusedBorder,
              disabledBorder: border(c.outlineVariant, 1),
              border: restingBorder,
            ),
          ),
        ),
        if (supportText != null) ...[
          SizedBox(height: spacing.xs),
          Semantics(
            liveRegion: hasError,
            child: Text(
              supportText,
              style: textTheme.bodySmall!.copyWith(color: supportColor),
            ),
          ),
        ],
      ],
    );
  }
}
