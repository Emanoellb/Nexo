// Valores das variáveis Colors/Semantic/* de nexo.lib.pen (lidos em 21/10/2026).
// A lib é a fonte da verdade: mudou um token lá, atualize aqui.
// Ver docs/frontend/tokens-flutter.md.

import 'package:flutter/material.dart';

/// Todas as cores semânticas do design system do Nexo.
///
/// Este é o único lugar do app com valores de cor. Os widgets leem
/// `Theme.of(context).colorScheme` (papéis do Material 3) ou
/// `context.nexoColors` (papéis que não existem no ColorScheme).
///
/// Dark mode futuro: criar `NexoColors.dark` com os mesmos campos.
@immutable
class NexoColors extends ThemeExtension<NexoColors> {
  const NexoColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.surface,
    required this.surfaceDim,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.cardDefault,
    required this.cardSecondary,
    required this.cardSelected,
    required this.cardBorder,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.disabledBackground,
    required this.disabledContent,
    required this.focus,
    required this.selected,
    required this.hover,
    required this.pressed,
    required this.scrim,
    required this.controlBorder,
    required this.glassFill,
    required this.glassSheen,
    required this.glassSheenEnd,
    required this.glassEdge,
    required this.glassIndicator,
    required this.glassPressed,
    required this.glassContent,
    required this.glassContentSelected,
    required this.glassFallback,
    required this.glassHighlight,
    required this.iconDefault,
    required this.iconSecondary,
    required this.iconSelected,
    required this.iconDisabled,
    required this.iconSuccess,
    required this.iconWarning,
    required this.iconError,
    required this.iconInfo,
  });

  /// Tema claro, o único do MVP.
  static const light = NexoColors(
    primary: Color(0xFF567792),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFEEF3F8),
    onPrimaryContainer: Color(0xFF24353F),
    secondary: Color(0xFF71658B),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFF2EFF7),
    onSecondaryContainer: Color(0xFF332C40),
    surface: Color(0xFFFAFAFB),
    surfaceDim: Color(0xFFF4F5F7),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF7F8F9),
    surfaceContainer: Color(0xFFF4F5F7),
    surfaceContainerHigh: Color(0xFFE7E9ED),
    onSurface: Color(0xFF1D2127),
    onSurfaceVariant: Color(0xFF666D78),
    outline: Color(0xFFAEB3BC),
    outlineVariant: Color(0xFFD5D8DE),
    cardDefault: Color(0xFFFFFFFF),
    cardSecondary: Color(0xFFF4F5F7),
    cardSelected: Color(0xFFEEF3F8),
    cardBorder: Color(0xFFE7E9ED),
    success: Color(0xFF507157),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFE0ECE3),
    onSuccessContainer: Color(0xFF25372A),
    error: Color(0xFFA34D52),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF6DFDF),
    onErrorContainer: Color(0xFF54272A),
    warning: Color(0xFF8F703F),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFF3E9D2),
    onWarningContainer: Color(0xFF463720),
    info: Color(0xFF4A6B84),
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFDDEAF3),
    onInfoContainer: Color(0xFF223642),
    disabledBackground: Color(0xFFE7E9ED),
    disabledContent: Color(0xFFAEB3BC),
    focus: Color(0xFF1D2127),
    selected: Color(0xFFEEF3F8),
    hover: Color(0x0F1D2127),
    pressed: Color(0x1A1D2127),
    scrim: Color(0x521D2127),
    controlBorder: Color(0xFF858B96),
    glassFill: Color(0xA3FFFFFF),
    glassSheen: Color(0x7AFFFFFF),
    glassSheenEnd: Color(0x00FFFFFF),
    glassEdge: Color(0x0F1D2127),
    glassIndicator: Color(0xA3D8E3EC),
    glassPressed: Color(0x1A1D2127),
    glassContent: Color(0xFF666D78),
    glassContentSelected: Color(0xFF435F76),
    glassFallback: Color(0xFFFFFFFF),
    glassHighlight: Color(0xCCFFFFFF),
    iconDefault: Color(0xFF1D2127),
    iconSecondary: Color(0xFF666D78),
    iconSelected: Color(0xFF567792),
    iconDisabled: Color(0xFFAEB3BC),
    iconSuccess: Color(0xFF507157),
    iconWarning: Color(0xFF8F703F),
    iconError: Color(0xFFA34D52),
    iconInfo: Color(0xFF4A6B84),
  );

  /// `Colors/Semantic/Primary`
  final Color primary;

  /// `Colors/Semantic/OnPrimary`
  final Color onPrimary;

  /// `Colors/Semantic/PrimaryContainer`
  final Color primaryContainer;

  /// `Colors/Semantic/OnPrimaryContainer`
  final Color onPrimaryContainer;

  /// `Colors/Semantic/Secondary`
  final Color secondary;

  /// `Colors/Semantic/OnSecondary`
  final Color onSecondary;

  /// `Colors/Semantic/SecondaryContainer`
  final Color secondaryContainer;

  /// `Colors/Semantic/OnSecondaryContainer`
  final Color onSecondaryContainer;

  /// `Colors/Semantic/Surface`
  final Color surface;

  /// `Colors/Semantic/SurfaceDim`
  final Color surfaceDim;

  /// `Colors/Semantic/SurfaceContainerLowest`
  final Color surfaceContainerLowest;

  /// `Colors/Semantic/SurfaceContainerLow`
  final Color surfaceContainerLow;

  /// `Colors/Semantic/SurfaceContainer`
  final Color surfaceContainer;

  /// `Colors/Semantic/SurfaceContainerHigh`
  final Color surfaceContainerHigh;

  /// `Colors/Semantic/OnSurface`
  final Color onSurface;

  /// `Colors/Semantic/OnSurfaceVariant`
  final Color onSurfaceVariant;

  /// `Colors/Semantic/Outline`
  final Color outline;

  /// `Colors/Semantic/OutlineVariant`
  final Color outlineVariant;

  /// `Colors/Semantic/Card/Default`
  final Color cardDefault;

  /// `Colors/Semantic/Card/Secondary`
  final Color cardSecondary;

  /// `Colors/Semantic/Card/Selected`
  final Color cardSelected;

  /// `Colors/Semantic/Card/Border`
  final Color cardBorder;

  /// `Colors/Semantic/Success`
  final Color success;

  /// `Colors/Semantic/OnSuccess`
  final Color onSuccess;

  /// `Colors/Semantic/SuccessContainer`
  final Color successContainer;

  /// `Colors/Semantic/OnSuccessContainer`
  final Color onSuccessContainer;

  /// `Colors/Semantic/Error`
  final Color error;

  /// `Colors/Semantic/OnError`
  final Color onError;

  /// `Colors/Semantic/ErrorContainer`
  final Color errorContainer;

  /// `Colors/Semantic/OnErrorContainer`
  final Color onErrorContainer;

  /// `Colors/Semantic/Warning`
  final Color warning;

  /// `Colors/Semantic/OnWarning`
  final Color onWarning;

  /// `Colors/Semantic/WarningContainer`
  final Color warningContainer;

  /// `Colors/Semantic/OnWarningContainer`
  final Color onWarningContainer;

  /// `Colors/Semantic/Info`
  final Color info;

  /// `Colors/Semantic/OnInfo`
  final Color onInfo;

  /// `Colors/Semantic/InfoContainer`
  final Color infoContainer;

  /// `Colors/Semantic/OnInfoContainer`
  final Color onInfoContainer;

  /// `Colors/Semantic/Disabled/Background`
  final Color disabledBackground;

  /// `Colors/Semantic/Disabled/Content`
  final Color disabledContent;

  /// `Colors/Semantic/Focus`
  final Color focus;

  /// `Colors/Semantic/Selected`
  final Color selected;

  /// `Colors/Semantic/Hover`
  final Color hover;

  /// `Colors/Semantic/Pressed`
  final Color pressed;

  /// `Colors/Semantic/Scrim`
  final Color scrim;

  /// `Colors/Semantic/Control/Border`
  final Color controlBorder;

  /// `Colors/Semantic/Glass/Fill`
  final Color glassFill;

  /// `Colors/Semantic/Glass/Sheen`
  final Color glassSheen;

  /// `Colors/Semantic/Glass/SheenEnd`
  final Color glassSheenEnd;

  /// `Colors/Semantic/Glass/Edge`
  final Color glassEdge;

  /// `Colors/Semantic/Glass/Indicator`
  final Color glassIndicator;

  /// `Colors/Semantic/Glass/Pressed`
  final Color glassPressed;

  /// `Colors/Semantic/Glass/Content`
  final Color glassContent;

  /// `Colors/Semantic/Glass/ContentSelected`
  final Color glassContentSelected;

  /// `Colors/Semantic/Glass/Fallback`
  final Color glassFallback;

  /// `Colors/Semantic/Glass/Highlight`
  final Color glassHighlight;

  /// `Colors/Semantic/Icon/Default`
  final Color iconDefault;

  /// `Colors/Semantic/Icon/Secondary`
  final Color iconSecondary;

  /// `Colors/Semantic/Icon/Selected`
  final Color iconSelected;

  /// `Colors/Semantic/Icon/Disabled`
  final Color iconDisabled;

  /// `Colors/Semantic/Icon/Success`
  final Color iconSuccess;

  /// `Colors/Semantic/Icon/Warning`
  final Color iconWarning;

  /// `Colors/Semantic/Icon/Error`
  final Color iconError;

  /// `Colors/Semantic/Icon/Info`
  final Color iconInfo;

  @override
  NexoColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? surface,
    Color? surfaceDim,
    Color? surfaceContainerLowest,
    Color? surfaceContainerLow,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? outline,
    Color? outlineVariant,
    Color? cardDefault,
    Color? cardSecondary,
    Color? cardSelected,
    Color? cardBorder,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? error,
    Color? onError,
    Color? errorContainer,
    Color? onErrorContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? disabledBackground,
    Color? disabledContent,
    Color? focus,
    Color? selected,
    Color? hover,
    Color? pressed,
    Color? scrim,
    Color? controlBorder,
    Color? glassFill,
    Color? glassSheen,
    Color? glassSheenEnd,
    Color? glassEdge,
    Color? glassIndicator,
    Color? glassPressed,
    Color? glassContent,
    Color? glassContentSelected,
    Color? glassFallback,
    Color? glassHighlight,
    Color? iconDefault,
    Color? iconSecondary,
    Color? iconSelected,
    Color? iconDisabled,
    Color? iconSuccess,
    Color? iconWarning,
    Color? iconError,
    Color? iconInfo,
  }) {
    return NexoColors(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      surface: surface ?? this.surface,
      surfaceDim: surfaceDim ?? this.surfaceDim,
      surfaceContainerLowest:
          surfaceContainerLowest ?? this.surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      outline: outline ?? this.outline,
      outlineVariant: outlineVariant ?? this.outlineVariant,
      cardDefault: cardDefault ?? this.cardDefault,
      cardSecondary: cardSecondary ?? this.cardSecondary,
      cardSelected: cardSelected ?? this.cardSelected,
      cardBorder: cardBorder ?? this.cardBorder,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorContainer: errorContainer ?? this.errorContainer,
      onErrorContainer: onErrorContainer ?? this.onErrorContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      disabledBackground: disabledBackground ?? this.disabledBackground,
      disabledContent: disabledContent ?? this.disabledContent,
      focus: focus ?? this.focus,
      selected: selected ?? this.selected,
      hover: hover ?? this.hover,
      pressed: pressed ?? this.pressed,
      scrim: scrim ?? this.scrim,
      controlBorder: controlBorder ?? this.controlBorder,
      glassFill: glassFill ?? this.glassFill,
      glassSheen: glassSheen ?? this.glassSheen,
      glassSheenEnd: glassSheenEnd ?? this.glassSheenEnd,
      glassEdge: glassEdge ?? this.glassEdge,
      glassIndicator: glassIndicator ?? this.glassIndicator,
      glassPressed: glassPressed ?? this.glassPressed,
      glassContent: glassContent ?? this.glassContent,
      glassContentSelected: glassContentSelected ?? this.glassContentSelected,
      glassFallback: glassFallback ?? this.glassFallback,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      iconDefault: iconDefault ?? this.iconDefault,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      iconSelected: iconSelected ?? this.iconSelected,
      iconDisabled: iconDisabled ?? this.iconDisabled,
      iconSuccess: iconSuccess ?? this.iconSuccess,
      iconWarning: iconWarning ?? this.iconWarning,
      iconError: iconError ?? this.iconError,
      iconInfo: iconInfo ?? this.iconInfo,
    );
  }

  @override
  NexoColors lerp(NexoColors? other, double t) {
    if (other == null) return this;
    return NexoColors(
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      onPrimaryContainer: Color.lerp(
        onPrimaryContainer,
        other.onPrimaryContainer,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      secondaryContainer: Color.lerp(
        secondaryContainer,
        other.secondaryContainer,
        t,
      )!,
      onSecondaryContainer: Color.lerp(
        onSecondaryContainer,
        other.onSecondaryContainer,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceDim: Color.lerp(surfaceDim, other.surfaceDim, t)!,
      surfaceContainerLowest: Color.lerp(
        surfaceContainerLowest,
        other.surfaceContainerLowest,
        t,
      )!,
      surfaceContainerLow: Color.lerp(
        surfaceContainerLow,
        other.surfaceContainerLow,
        t,
      )!,
      surfaceContainer: Color.lerp(
        surfaceContainer,
        other.surfaceContainer,
        t,
      )!,
      surfaceContainerHigh: Color.lerp(
        surfaceContainerHigh,
        other.surfaceContainerHigh,
        t,
      )!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(
        onSurfaceVariant,
        other.onSurfaceVariant,
        t,
      )!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
      cardDefault: Color.lerp(cardDefault, other.cardDefault, t)!,
      cardSecondary: Color.lerp(cardSecondary, other.cardSecondary, t)!,
      cardSelected: Color.lerp(cardSelected, other.cardSelected, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      onErrorContainer: Color.lerp(
        onErrorContainer,
        other.onErrorContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      disabledBackground: Color.lerp(
        disabledBackground,
        other.disabledBackground,
        t,
      )!,
      disabledContent: Color.lerp(disabledContent, other.disabledContent, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      pressed: Color.lerp(pressed, other.pressed, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      controlBorder: Color.lerp(controlBorder, other.controlBorder, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassSheen: Color.lerp(glassSheen, other.glassSheen, t)!,
      glassSheenEnd: Color.lerp(glassSheenEnd, other.glassSheenEnd, t)!,
      glassEdge: Color.lerp(glassEdge, other.glassEdge, t)!,
      glassIndicator: Color.lerp(glassIndicator, other.glassIndicator, t)!,
      glassPressed: Color.lerp(glassPressed, other.glassPressed, t)!,
      glassContent: Color.lerp(glassContent, other.glassContent, t)!,
      glassContentSelected: Color.lerp(
        glassContentSelected,
        other.glassContentSelected,
        t,
      )!,
      glassFallback: Color.lerp(glassFallback, other.glassFallback, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
      iconDefault: Color.lerp(iconDefault, other.iconDefault, t)!,
      iconSecondary: Color.lerp(iconSecondary, other.iconSecondary, t)!,
      iconSelected: Color.lerp(iconSelected, other.iconSelected, t)!,
      iconDisabled: Color.lerp(iconDisabled, other.iconDisabled, t)!,
      iconSuccess: Color.lerp(iconSuccess, other.iconSuccess, t)!,
      iconWarning: Color.lerp(iconWarning, other.iconWarning, t)!,
      iconError: Color.lerp(iconError, other.iconError, t)!,
      iconInfo: Color.lerp(iconInfo, other.iconInfo, t)!,
    );
  }
}
