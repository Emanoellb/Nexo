import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';

/// `Feedback/Progress/Circular` da lib: anel com trilho em
/// SurfaceContainerHigh e indicador em Primary, espessura de 10% do tamanho
/// (raio interno 0,8). Sem [value], é indeterminado.
///
/// Anuncia o carregamento ao leitor de tela por [semanticsLabel]. Continua
/// girando com "reduzir movimento": mostra um estado, não é decoração.
class NexoCircularProgress extends StatelessWidget {
  const NexoCircularProgress({
    super.key,
    this.size = defaultSize,
    this.value,
    this.semanticsLabel = 'Carregando',
  });

  static const double defaultSize = 40;

  final double size;

  /// 0–1; `null` = indeterminado.
  final double? value;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    return Semantics(
      liveRegion: true,
      child: SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(
          value: value,
          strokeWidth: size / 10,
          color: c.primary,
          backgroundColor: c.surfaceContainerHigh,
          semanticsLabel: semanticsLabel,
        ),
      ),
    );
  }
}
