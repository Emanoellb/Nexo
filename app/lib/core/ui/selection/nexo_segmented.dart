import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';

/// `Selection/Segmented` da lib: escolha única entre 2–4 visões do mesmo
/// conteúdo (ex.: "Tarefas | Disciplinas"). Fundo SurfaceContainer,
/// `Shape/MD`, padding XS; o selecionado em PrimaryContainer, rótulo
/// OnPrimaryContainer 600; os outros em OnSurfaceVariant 500.
///
/// Altura total = `Size/Target` (48). O alvo de cada segmento é a faixa
/// inteira (48, incluindo o padding XS em volta da pílula), não só a pílula
/// de 40: o Nexo mantém alvo ≥ 48 (a lib desenha 44).
class NexoSegmented<T> extends StatelessWidget {
  const NexoSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<({T value, String label})> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final shape = context.shape;
    final half = spacing.xs / 2;
    return Container(
      constraints: BoxConstraints(minHeight: context.sizes.target),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(shape.md),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, segment) in segments.indexed)
              Expanded(
                child: _Segment(
                  label: segment.label,
                  selected: segment.value == selected,
                  position: i + 1,
                  count: segments.length,
                  // Padding XS em volta; XS entre as pílulas.
                  inset: EdgeInsetsDirectional.fromSTEB(
                    i == 0 ? spacing.xs : half,
                    spacing.xs,
                    i == segments.length - 1 ? spacing.xs : half,
                    spacing.xs,
                  ),
                  onTap: () => onChanged(segment.value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.position,
    required this.count,
    required this.inset,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final int position;
  final int count;
  final EdgeInsetsGeometry inset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final radius = BorderRadius.circular(context.shape.sm);
    final style = context
        .textStyle(
          selected
              ? NexoTextStyles.labelMediumEmphasis
              : NexoTextStyles.labelMedium,
        )
        .copyWith(color: selected ? c.onPrimaryContainer : c.onSurfaceVariant);
    return Semantics(
      button: true,
      selected: selected,
      // Escolha única: o leitor de tela anuncia como grupo (como o
      // SegmentedButton do Flutter).
      inMutuallyExclusiveGroup: true,
      label: '$label, $position de $count',
      onTap: onTap,
      excludeSemantics: true,
      // A faixa inteira responde ao toque; a pílula mostra o estado.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: inset,
          child: NexoTappable(
            onTap: onTap,
            borderRadius: radius,
            color: selected ? c.primaryContainer : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: context.sizes.target - context.spacing.xs * 2,
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: style,
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
