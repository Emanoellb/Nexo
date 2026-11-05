// Valores das variáveis Typography/* e typeface de nexo.lib.pen.
// Mapeamento para os 15 slots do Material 3 em docs/frontend/tokens-flutter.md.

import 'package:flutter/material.dart';

/// Família empacotada em assets/fonts (Manrope variável, SIL OFL 1.1).
const String nexoFontFamily = 'Manrope';

/// Estilo base. A fonte é variável: o peso vai em `fontWeight` e também no
/// eixo `wght`, para não depender de o motor mapear um no outro.
TextStyle _style(double size, int weight, double height) {
  return TextStyle(
    fontFamily: nexoFontFamily,
    fontSize: size,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation.weight(weight.toDouble())],
    height: height,
    letterSpacing: 0,
  );
}

/// Papéis tipográficos do design system, com o nome usado na lib.
abstract final class NexoTextStyles {
  /// `Typography/DisplayLarge` 32/700
  static final displayLarge = _style(32, 700, 1.25);

  /// `Typography/HeadingLarge` 28/700
  static final headingLarge = _style(28, 700, 1.2857142857);

  /// `Typography/HeadingMedium` 24/600
  static final headingMedium = _style(24, 600, 1.3333333333);

  /// `Typography/TitleLarge` 20/600
  static final titleLarge = _style(20, 600, 1.4);

  /// `Typography/TitleMedium` 18/600
  static final titleMedium = _style(18, 600, 1.3333333333);

  /// `Typography/BodyLarge` 16/400
  static final bodyLarge = _style(16, 400, 1.5);

  /// `Typography/BodyMedium` 14/400
  static final bodyMedium = _style(14, 400, 1.4285714286);

  /// `Typography/LabelMedium` 14/500
  static final labelMedium = _style(14, 500, 1.4285714286);

  /// `Typography/LabelMedium` com `Typography/Weight/Emphasis` (600):
  /// rótulo dos botões e títulos de Alert.
  static final labelMediumEmphasis = _style(14, 600, 1.4285714286);

  /// `Typography/LabelSmall` 12/500
  static final labelSmall = _style(12, 500, 1.3333333333);

  /// `Typography/LabelSmall` com `Typography/Weight/Emphasis` (600): nome do
  /// destino selecionado da barra de navegação (Navigation/BottomBar).
  static final labelSmallEmphasis = _style(12, 600, 1.3333333333);

  /// `Typography/DisplayTimer` 56/600. Só no Nexo/FocusTimer.
  static final displayTimer = _style(56, 600, 1.1428571429);
}

/// TextTheme do Material 3 preenchido a partir dos papéis da lib.
///
/// A lib tem 9 papéis e o M3 tem 15. Os slots sem papel próprio repetem
/// o papel mais próximo (marcados com "alias").
TextTheme nexoTextTheme(Color onSurface) {
  final theme = TextTheme(
    displayLarge: NexoTextStyles.displayLarge,
    displayMedium: NexoTextStyles.displayLarge, // alias
    displaySmall: NexoTextStyles.displayLarge, // alias
    headlineLarge: NexoTextStyles.headingLarge,
    headlineMedium: NexoTextStyles.headingMedium,
    headlineSmall: NexoTextStyles.headingMedium, // alias (título do Dialog)
    titleLarge: NexoTextStyles.titleLarge,
    titleMedium: NexoTextStyles.titleMedium,
    titleSmall: NexoTextStyles.labelMediumEmphasis, // alias
    bodyLarge: NexoTextStyles.bodyLarge,
    bodyMedium: NexoTextStyles.bodyMedium,
    bodySmall: NexoTextStyles.labelSmall, // alias (helper dos campos)
    labelLarge: NexoTextStyles.labelMediumEmphasis, // rótulo de botão
    labelMedium: NexoTextStyles.labelMedium,
    labelSmall: NexoTextStyles.labelSmall,
  );
  return theme.apply(bodyColor: onSurface, displayColor: onSurface);
}
