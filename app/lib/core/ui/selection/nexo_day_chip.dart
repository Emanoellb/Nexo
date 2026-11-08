import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';
import 'nexo_filter_chip.dart';

/// Variante "dia da semana" do `Chip/Filter` (Criar plano 04 e Editar
/// plano): visual de 36 (`Shape/SM`) com a inicial (LabelMedium); marcado em
/// Primary com OnPrimary, desmarcado em SurfaceContainer com
/// OnSurfaceVariant. Escolha múltipla (o leitor de tela anuncia ligado ou
/// desligado), sem o check do Chip/Filter de escolha única.
///
/// Alvo de 48 de altura; [width] fixa a largura (≥ 48 na grade em duas
/// linhas), ou ocupa a largura dada pelo pai.
class NexoDayChip extends StatelessWidget {
  const NexoDayChip({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.selected,
    required this.onChanged,
    this.width,
  });

  /// Inicial do dia ("S").
  final String label;

  /// Nome completo do dia ("segunda").
  final String semanticsLabel;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    void toggle() => onChanged(!selected);
    return Semantics(
      button: true,
      toggled: selected,
      label: semanticsLabel,
      onTap: toggle,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: context.sizes.target,
        child: Center(
          child: NexoTappable(
            onTap: toggle,
            borderRadius: BorderRadius.circular(context.shape.sm),
            color: selected ? c.primary : c.surfaceContainer,
            child: SizedBox(
              height: NexoFilterChip.visualHeight,
              width: width ?? double.infinity,
              child: Center(
                child: Text(
                  label,
                  style: context
                      .textStyle(NexoTextStyles.labelMedium)
                      .copyWith(
                        color: selected ? c.onPrimary : c.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
