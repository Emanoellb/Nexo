// Valor da variável Glass/Blur de nexo.lib.pen. As cores do vidro
// (Colors/Semantic/Glass/*) ficam em NexoColors. Ver docs/frontend/tokens-flutter.md.

import 'package:flutter/material.dart';

/// `Glass/Blur`: desfoque do fundo atrás das superfícies "Nexo Glass".
@immutable
class NexoGlass extends ThemeExtension<NexoGlass> {
  const NexoGlass({required this.blur});

  static const standard = NexoGlass(blur: 24);

  /// `Glass/Blur`, em px lógicos (sigma do desfoque).
  final double blur;

  @override
  NexoGlass copyWith({double? blur}) => NexoGlass(blur: blur ?? this.blur);

  @override
  NexoGlass lerp(NexoGlass? other, double t) => other ?? this;
}
