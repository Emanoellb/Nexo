import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';

/// `Navigation/PageControl` da lib: de 3 a 5 pontos. O passo atual é uma
/// pílula de 20 × 8 em Primary; os outros, pontos de 8 × 8 em Control/Border.
///
/// Só indica o passo. Para o leitor de tela, é lido como "Passo X de N".
class NexoPageControl extends StatelessWidget {
  const NexoPageControl({super.key, required this.count, required this.index})
    : assert(count >= 3 && count <= 5, 'A lib define de 3 a 5 passos.'),
      assert(index >= 0 && index < count);

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final motion = context.motion;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : motion.short;

    return Semantics(
      label: 'Passo ${index + 1} de $count',
      excludeSemantics: true,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.lg),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) SizedBox(width: spacing.sm),
                AnimatedContainer(
                  duration: duration,
                  curve: motion.standard,
                  width: i == index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == index ? c.primary : c.controlBorder,
                    borderRadius: BorderRadius.circular(context.shape.full),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
