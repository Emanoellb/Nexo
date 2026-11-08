import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../buttons/nexo_icon_button.dart';

/// Ajuste com − e + (design do Criar plano, "Meta diária" e "× por
/// semana"): controle de 48 em SurfaceContainerLowest com borda
/// Control/Border e `Shape/MD`, o valor no meio (LabelMedium) e a ajuda
/// embaixo. Para o leitor de tela: o nome e o valor, e os botões
/// "Diminuir" e "Aumentar".
class NexoStepper extends StatelessWidget {
  const NexoStepper({
    super.key,
    required this.label,
    required this.valueText,
    required this.onDecrement,
    required this.onIncrement,
    this.helper,
    this.decrementTooltip = 'Diminuir',
    this.incrementTooltip = 'Aumentar',
  });

  /// Nome para o leitor de tela (o rótulo visível fica fora, na tela).
  final String label;
  final String valueText;

  /// `null` desabilita o botão (no limite).
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final String? helper;
  final String decrementTooltip;
  final String incrementTooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          container: true,
          label: label,
          value: valueText,
          child: Container(
            constraints: BoxConstraints(minHeight: context.sizes.target),
            decoration: BoxDecoration(
              color: c.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(context.shape.md),
              border: Border.all(color: c.controlBorder),
            ),
            child: Row(
              children: [
                NexoIconButton(
                  icon: LucideIcons.minus,
                  tooltip: decrementTooltip,
                  iconSize: 20,
                  color: c.iconDefault,
                  onPressed: onDecrement,
                ),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      valueText,
                      textAlign: TextAlign.center,
                      style: context
                          .textStyle(NexoTextStyles.labelMediumEmphasis)
                          .copyWith(color: c.onSurface),
                    ),
                  ),
                ),
                NexoIconButton(
                  icon: LucideIcons.plus,
                  tooltip: incrementTooltip,
                  iconSize: 20,
                  color: c.iconDefault,
                  onPressed: onIncrement,
                ),
              ],
            ),
          ),
        ),
        if (helper != null) ...[
          SizedBox(height: spacing.xs),
          Text(
            helper!,
            style: textTheme.bodySmall!.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
