import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';

/// `Feedback/Progress/Linear` da lib: trilho de 4 px em SurfaceContainerHigh
/// e indicador arredondado. Progresso e conquistas usam Secondary (padrão);
/// um dia cumprido usa Success.
///
/// Sempre ao lado de um rótulo de valor visível; o leitor de tela recebe
/// [semanticsValue] (ex.: "1h 10min de 1h 30min").
class NexoLinearProgress extends StatelessWidget {
  const NexoLinearProgress({
    super.key,
    required this.value,
    this.color,
    this.semanticsLabel,
    this.semanticsValue,
  });

  static const double height = 4;

  /// 0–1 (valores fora são limitados).
  final double value;

  /// Padrão: `Secondary`.
  final Color? color;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final radius = BorderRadius.circular(context.shape.full);
    final fraction = value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticsLabel,
      value: semanticsValue ?? '${(fraction * 100).round()}%',
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: c.surfaceContainerHigh),
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: fraction,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color ?? c.secondary,
                    borderRadius: radius,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
