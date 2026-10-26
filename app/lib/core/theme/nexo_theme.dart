import 'package:flutter/material.dart';

import 'nexo_colors.dart';
import 'nexo_dimensions.dart';
import 'nexo_typography.dart';

export 'nexo_colors.dart';
export 'nexo_dimensions.dart';
export 'nexo_typography.dart';

/// Monta o ThemeData do Nexo a partir dos tokens.
///
/// Só existe o tema claro no MVP. Para o dark mode: criar `NexoColors.dark`
/// e `NexoElevation.dark` e chamar `NexoTheme.build` com eles.
abstract final class NexoTheme {
  static ThemeData light() => build(
    brightness: Brightness.light,
    colors: NexoColors.light,
    elevation: NexoElevation.light,
  );

  static ThemeData build({
    required Brightness brightness,
    required NexoColors colors,
    required NexoElevation elevation,
  }) {
    final scheme = colorSchemeFrom(colors, brightness);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: nexoFontFamily,
      textTheme: nexoTextTheme(colors.onSurface),
      scaffoldBackgroundColor: colors.surface,
      splashFactory: InkRipple.splashFactory,
      extensions: [
        colors,
        elevation,
        NexoSpacing.standard,
        NexoShape.standard,
        NexoMotion.standardMotion,
      ],
    );
  }

  /// Papéis do ColorScheme (M3). Os que a lib não tem usam um alias,
  /// documentado em docs/frontend/tokens-flutter.md.
  static ColorScheme colorSchemeFrom(NexoColors c, Brightness brightness) {
    return ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.secondary,
      onSecondary: c.onSecondary,
      secondaryContainer: c.secondaryContainer,
      onSecondaryContainer: c.onSecondaryContainer,
      tertiary: c.secondary, // alias: a lib não tem Tertiary
      onTertiary: c.onSecondary,
      tertiaryContainer: c.secondaryContainer,
      onTertiaryContainer: c.onSecondaryContainer,
      error: c.error,
      onError: c.onError,
      errorContainer: c.errorContainer,
      onErrorContainer: c.onErrorContainer,
      surface: c.surface,
      onSurface: c.onSurface,
      onSurfaceVariant: c.onSurfaceVariant,
      surfaceDim: c.surfaceDim,
      surfaceBright: c.surface, // alias
      surfaceContainerLowest: c.surfaceContainerLowest,
      surfaceContainerLow: c.surfaceContainerLow,
      surfaceContainer: c.surfaceContainer,
      surfaceContainerHigh: c.surfaceContainerHigh,
      surfaceContainerHighest: c.surfaceContainerHigh, // alias
      outline: c.outline,
      outlineVariant: c.outlineVariant,
      shadow: c.onSurface, // a cor-base das sombras da lib é Neutral/900
      scrim: c.scrim,
      inverseSurface: c.onSurface, // botão Apple: OnSurface com texto Surface
      onInverseSurface: c.surface,
      inversePrimary: c.primaryContainer, // alias
      surfaceTint: Colors.transparent, // o Nexo usa sombra, não tinta
    );
  }
}

/// Atalhos para os tokens que não estão no ThemeData padrão.
extension NexoThemeContext on BuildContext {
  NexoColors get nexoColors => Theme.of(this).extension<NexoColors>()!;
  NexoSpacing get spacing => Theme.of(this).extension<NexoSpacing>()!;
  NexoShape get shape => Theme.of(this).extension<NexoShape>()!;
  NexoElevation get elevation => Theme.of(this).extension<NexoElevation>()!;
  NexoMotion get motion => Theme.of(this).extension<NexoMotion>()!;
}
