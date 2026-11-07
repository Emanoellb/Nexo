// Valores das variáveis Spacing/*, Size/*, Shape/*, Elevation/*, Motion/* e
// Glass/Blur de nexo.lib.pen. Ver docs/frontend/tokens-flutter.md.

import 'package:flutter/material.dart';

/// `Spacing/*`. Escala de espaçamento em px lógicos.
@immutable
class NexoSpacing extends ThemeExtension<NexoSpacing> {
  const NexoSpacing({
    required this.none,
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.xxxl,
    required this.xxxxl,
  });

  static const standard = NexoSpacing(
    none: 0,
    xxs: 2,
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 24,
    xxl: 32,
    xxxl: 48,
    xxxxl: 64,
  );

  /// `Spacing/0`
  final double none;

  /// `Spacing/2XS` (2): respiros mínimos, como título e texto de um aviso
  /// (decisão de 04/11/2026; a criar na lib).
  final double xxs;

  /// `Spacing/XS`
  final double xs;

  /// `Spacing/SM`
  final double sm;

  /// `Spacing/MD`
  final double md;

  /// `Spacing/LG`
  final double lg;

  /// `Spacing/XL`
  final double xl;

  /// `Spacing/2XL`
  final double xxl;

  /// `Spacing/3XL`
  final double xxxl;

  /// `Spacing/4XL`
  final double xxxxl;

  @override
  NexoSpacing copyWith({
    double? none,
    double? xxs,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
    double? xxxl,
    double? xxxxl,
  }) {
    return NexoSpacing(
      none: none ?? this.none,
      xxs: xxs ?? this.xxs,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
      xxxl: xxxl ?? this.xxxl,
      xxxxl: xxxxl ?? this.xxxxl,
    );
  }

  @override
  NexoSpacing lerp(NexoSpacing? other, double t) => other ?? this;
}

/// `Size/*`. Medidas fixas compartilhadas entre componentes.
@immutable
class NexoSizes extends ThemeExtension<NexoSizes> {
  const NexoSizes({required this.target});

  static const standard = NexoSizes(target: 48);

  /// `Size/Target` (48): alvo mínimo de toque e altura dos controles
  /// (botão, campo, Snackbar). Decisão de 04/11/2026; a criar na lib.
  final double target;

  @override
  NexoSizes copyWith({double? target}) =>
      NexoSizes(target: target ?? this.target);

  @override
  NexoSizes lerp(NexoSizes? other, double t) => other ?? this;
}

/// `Shape/*`. Raios de canto. `full` deixa a forma em pílula.
@immutable
class NexoShape extends ThemeExtension<NexoShape> {
  const NexoShape({
    required this.none,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.full,
  });

  static const standard = NexoShape(
    none: 0,
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 24,
    full: 999,
  );

  /// `Shape/None`
  final double none;

  /// `Shape/XS`
  final double xs;

  /// `Shape/SM`
  final double sm;

  /// `Shape/MD`
  final double md;

  /// `Shape/LG`
  final double lg;

  /// `Shape/XL`
  final double xl;

  /// `Shape/Full`
  final double full;

  BorderRadius radius(double value) => BorderRadius.circular(value);

  @override
  NexoShape copyWith({
    double? none,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? full,
  }) {
    return NexoShape(
      none: none ?? this.none,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      full: full ?? this.full,
    );
  }

  @override
  NexoShape lerp(NexoShape? other, double t) => other ?? this;
}

/// `Elevation/0..5`. Uma sombra por nível (X, Y, Blur, Color).
///
/// Iguais nos temas claro e escuro (decisão de 04/11/2026): no escuro, a
/// elevação aparece pelo tom mais claro da superfície e pela borda.
@immutable
class NexoElevation extends ThemeExtension<NexoElevation> {
  const NexoElevation({required this.levels});

  static const standard = NexoElevation(
    levels: [
      [BoxShadow(color: Color(0x001D2127))],
      [
        BoxShadow(
          color: Color(0x0D1D2127),
          offset: Offset(0, 1),
          blurRadius: 4,
        ),
      ],
      [
        BoxShadow(
          color: Color(0x121D2127),
          offset: Offset(0, 2),
          blurRadius: 8,
        ),
      ],
      [
        BoxShadow(
          color: Color(0x171D2127),
          offset: Offset(0, 4),
          blurRadius: 16,
        ),
      ],
      [
        BoxShadow(
          color: Color(0x1A1D2127),
          offset: Offset(0, 6),
          blurRadius: 24,
        ),
      ],
      [
        BoxShadow(
          color: Color(0x1C1D2127),
          offset: Offset(0, 8),
          blurRadius: 32,
        ),
      ],
    ],
  );

  /// Índice = nível (`Elevation/0` a `Elevation/5`).
  final List<List<BoxShadow>> levels;

  List<BoxShadow> level(int value) => levels[value.clamp(0, levels.length - 1)];

  @override
  NexoElevation copyWith({List<List<BoxShadow>>? levels}) {
    return NexoElevation(levels: levels ?? this.levels);
  }

  @override
  NexoElevation lerp(NexoElevation? other, double t) {
    if (other == null) return this;
    return NexoElevation(
      levels: [
        for (var i = 0; i < levels.length; i++)
          BoxShadow.lerpList(levels[i], other.levels[i], t)!,
      ],
    );
  }
}

/// `Motion/*`. Durações, curvas e distâncias de animação.
@immutable
class NexoMotion extends ThemeExtension<NexoMotion> {
  const NexoMotion({
    required this.instant,
    required this.short,
    required this.medium,
    required this.long,
    required this.standard,
    required this.enter,
    required this.exit,
    required this.emphasized,
    required this.distanceSmall,
    required this.distanceMedium,
    required this.distanceLarge,
    required this.pulse,
    required this.pulseMinOpacity,
  });

  static const standardMotion = NexoMotion(
    instant: Duration(milliseconds: 100),
    short: Duration(milliseconds: 150),
    medium: Duration(milliseconds: 250),
    long: Duration(milliseconds: 350),
    standard: Cubic(0.4, 0, 0.2, 1),
    enter: Cubic(0, 0, 0.2, 1),
    exit: Cubic(0.4, 0, 1, 1),
    emphasized: Cubic(0.2, 0, 0, 1),
    distanceSmall: 4,
    distanceMedium: 8,
    distanceLarge: 16,
    pulse: Duration(milliseconds: 1050),
    pulseMinOpacity: 0.55,
  );

  /// `Motion/Duration/Instant`
  final Duration instant;

  /// `Motion/Duration/Short`
  final Duration short;

  /// `Motion/Duration/Medium`
  final Duration medium;

  /// `Motion/Duration/Long`
  final Duration long;

  /// `Motion/Easing/Standard`
  final Curve standard;

  /// `Motion/Easing/Enter`
  final Curve enter;

  /// `Motion/Easing/Exit`
  final Curve exit;

  /// `Motion/Easing/Emphasized`
  final Curve emphasized;

  /// `Motion/Distance/Small`
  final double distanceSmall;

  /// `Motion/Distance/Medium`
  final double distanceMedium;

  /// `Motion/Distance/Large`
  final double distanceLarge;

  /// `Motion/Duration/Pulse` (1050 ms): meia-volta do pulso do skeleton
  /// (com reverse, em laço). Lib, 05/11/2026.
  final Duration pulse;

  /// `Motion/Opacity/PulseMin` (0,55): opacidade mínima do pulso (vai até 1).
  final double pulseMinOpacity;

  @override
  NexoMotion copyWith({
    Duration? instant,
    Duration? short,
    Duration? medium,
    Duration? long,
    Curve? standard,
    Curve? enter,
    Curve? exit,
    Curve? emphasized,
    double? distanceSmall,
    double? distanceMedium,
    double? distanceLarge,
    Duration? pulse,
    double? pulseMinOpacity,
  }) {
    return NexoMotion(
      instant: instant ?? this.instant,
      short: short ?? this.short,
      medium: medium ?? this.medium,
      long: long ?? this.long,
      standard: standard ?? this.standard,
      enter: enter ?? this.enter,
      exit: exit ?? this.exit,
      emphasized: emphasized ?? this.emphasized,
      distanceSmall: distanceSmall ?? this.distanceSmall,
      distanceMedium: distanceMedium ?? this.distanceMedium,
      distanceLarge: distanceLarge ?? this.distanceLarge,
      pulse: pulse ?? this.pulse,
      pulseMinOpacity: pulseMinOpacity ?? this.pulseMinOpacity,
    );
  }

  @override
  NexoMotion lerp(NexoMotion? other, double t) => other ?? this;
}
