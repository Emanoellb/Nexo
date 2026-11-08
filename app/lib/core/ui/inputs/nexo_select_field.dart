import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';

/// `Input/Select` e `Input/Time` da lib (`d:l0ERmP`, `d:LfjqJ`): rótulo
/// (LabelMedium), controle de 48 em SurfaceContainerLowest com borda
/// Control/Border e `Shape/MD`, ícone opcional no começo, valor
/// (BodyMedium) e o ícone do fim (chevron no Select, relógio no Time,
/// calendário no prazo). Sem valor, mostra [placeholder] em
/// OnSurfaceVariant.
///
/// O campo não abre nada sozinho: [onTap] recebe o retângulo do controle
/// para a tela ancorar o `Menu/Select` ou abrir o seletor de data e hora.
/// [errorText] troca a ajuda e pinta o texto em Error: é um aviso sobre o
/// valor (ex.: prazo vencido), não um erro de digitação.
class NexoSelectField extends StatelessWidget {
  const NexoSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.leadingIcon,
    this.trailingIcon = LucideIcons.chevronDown,
    this.helperText,
    this.errorText,
  });

  final String label;

  /// `null` mostra [placeholder].
  final String? value;
  final String placeholder;
  final ValueChanged<Rect>? onTap;
  final IconData? leadingIcon;
  final IconData trailingIcon;
  final String? helperText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final enabled = onTap != null;
    final support = errorText ?? helperText;
    final radius = BorderRadius.circular(context.shape.md);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: textTheme.labelMedium!.copyWith(
              color: enabled ? c.onSurface : c.disabledContent,
            ),
          ),
        ),
        SizedBox(height: spacing.sm),
        Builder(
          builder: (controlContext) {
            void tap() {
              final box = controlContext.findRenderObject()! as RenderBox;
              onTap!(box.localToGlobal(Offset.zero) & box.size);
            }

            return Semantics(
              button: true,
              enabled: enabled,
              label: label,
              value: value ?? placeholder,
              onTap: enabled ? tap : null,
              excludeSemantics: true,
              child: NexoTappable(
                onTap: enabled ? tap : null,
                borderRadius: radius,
                color: enabled
                    ? c.surfaceContainerLowest
                    : c.disabledBackground,
                child: Container(
                  constraints: BoxConstraints(minHeight: context.sizes.target),
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.lg,
                    vertical: spacing.sm,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: enabled ? c.controlBorder : c.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (leadingIcon != null) ...[
                        Icon(
                          leadingIcon,
                          size: 20,
                          color: enabled ? c.iconSecondary : c.iconDisabled,
                        ),
                        SizedBox(width: spacing.sm),
                      ],
                      Expanded(
                        child: Text(
                          value ?? placeholder,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium!.copyWith(
                            color: !enabled
                                ? c.disabledContent
                                : value == null
                                ? c.onSurfaceVariant
                                : c.onSurface,
                          ),
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      Icon(
                        trailingIcon,
                        size: 20,
                        color: enabled ? c.iconSecondary : c.iconDisabled,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (support != null) ...[
          SizedBox(height: spacing.xs),
          Semantics(
            liveRegion: errorText != null,
            child: Text(
              support,
              style: textTheme.bodySmall!.copyWith(
                color: errorText != null ? c.error : c.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
