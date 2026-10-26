import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';

/// `Selection/Checkbox` da lib: alvo circular de 48 px, caixa visual de
/// 20 px, rótulo e texto de apoio opcionais.
///
/// Estados: Unchecked, Checked, Indeterminate (`value == null`), Disabled
/// (`onChanged == null`), Pressed e Focused (no alvo).
///
/// Tocar no rótulo também marca. Links dentro de [label] (ex.: "Termos de
/// Uso") continuam abrindo o próprio destino.
class NexoCheckbox extends StatelessWidget {
  const NexoCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.labelText,
    this.helperText,
    this.semanticLabel,
    this.focusNode,
  }) : assert(label == null || labelText == null);

  /// `true`, `false` ou `null` (indeterminado).
  final bool? value;
  final ValueChanged<bool>? onChanged;

  /// Rótulo rico (com links). Para texto simples, use [labelText].
  final Widget? label;
  final String? labelText;
  final String? helperText;

  /// Nome lido pelo leitor de tela quando [label] é um widget.
  final String? semanticLabel;
  final FocusNode? focusNode;

  void _toggle() => onChanged?.call(!(value ?? false));

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final enabled = onChanged != null;
    final selected = value != false;

    final box = Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: !enabled
            ? c.disabledBackground
            : selected
            ? c.primary
            : c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(context.shape.xs),
        border: Border.all(
          width: 2,
          color: !enabled
              ? c.outlineVariant
              : selected
              ? c.primary
              : c.controlBorder,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Icon(
              value == null ? LucideIcons.minus : LucideIcons.check,
              size: 16,
              color: enabled ? c.onPrimary : c.iconDisabled,
            )
          : null,
    );

    final target = NexoTappable(
      onTap: enabled ? _toggle : null,
      focusNode: focusNode,
      borderRadius: BorderRadius.circular(context.shape.full),
      focusRingOutside: false,
      child: SizedBox.square(dimension: 48, child: Center(child: box)),
    );

    final hasCopy = label != null || labelText != null || helperText != null;
    final copyColor = enabled ? c.onSurface : c.disabledContent;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        target,
        if (hasCopy) ...[
          SizedBox(width: spacing.sm),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? _toggle : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (label != null)
                    DefaultTextStyle.merge(
                      style: textTheme.labelMedium!.copyWith(color: copyColor),
                      child: label!,
                    ),
                  if (labelText != null)
                    Text(
                      labelText!,
                      style: textTheme.labelMedium!.copyWith(color: copyColor),
                    ),
                  if (helperText != null) ...[
                    SizedBox(height: spacing.xs),
                    Text(
                      helperText!,
                      style: textTheme.labelSmall!.copyWith(
                        color: enabled ? c.onSurfaceVariant : c.disabledContent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );

    return Semantics(
      container: true,
      checked: value ?? false,
      mixed: value == null,
      enabled: enabled,
      label: semanticLabel ?? labelText,
      onTap: enabled ? _toggle : null,
      child: label == null
          ? ExcludeSemantics(child: row)
          // Rótulo rico: mantém os links acessíveis como nós próprios.
          : row,
    );
  }
}
