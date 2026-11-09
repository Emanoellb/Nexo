import 'package:flutter/material.dart';

/// Mostra um modal (diálogo, menu) com entrada e saída de durações
/// diferentes: abrir em Medium ou Short, fechar mais curto (padrão de
/// transições, 08/11/2026). É o `showGeneralDialog` com [reverseDuration].
Future<T?> showNexoModal<T>(
  BuildContext context, {
  required RoutePageBuilder pageBuilder,
  required RouteTransitionsBuilder transitionBuilder,
  required Duration duration,
  required Duration reverseDuration,
  required String barrierLabel,
  required Color barrierColor,
  bool barrierDismissible = true,
}) => Navigator.of(context, rootNavigator: true).push<T>(
  _NexoModalRoute<T>(
    pageBuilder: pageBuilder,
    transitionBuilder: transitionBuilder,
    transitionDuration: duration,
    reverseDuration: reverseDuration,
    barrierLabel: barrierLabel,
    barrierColor: barrierColor,
    barrierDismissible: barrierDismissible,
  ),
);

class _NexoModalRoute<T> extends RawDialogRoute<T> {
  _NexoModalRoute({
    required super.pageBuilder,
    required super.transitionBuilder,
    required super.transitionDuration,
    required this.reverseDuration,
    required super.barrierLabel,
    required super.barrierColor,
    required super.barrierDismissible,
  });

  final Duration reverseDuration;

  @override
  Duration get reverseTransitionDuration => reverseDuration;
}

/// Cresce de [from] a 1 **só na entrada** (Enter); ao fechar fica em 1 e
/// quem chama só esmaece (transições §4 e §8.4: Dialog e menus saem só
/// esmaecendo). Com [origin] (global, numa página de tela inteira), cresce
/// a partir desse ponto; sem ele, do centro.
class NexoEnterScale extends StatelessWidget {
  const NexoEnterScale({
    super.key,
    required this.animation,
    required this.from,
    required this.curve,
    required this.child,
    this.origin,
  });

  final Animation<double> animation;
  final double from;
  final Curve curve;
  final Offset? origin;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final closing = animation.status == AnimationStatus.reverse;
      final t = closing ? 1.0 : curve.transform(animation.value);
      final scale = from + (1 - from) * t;
      return origin == null
          ? Transform.scale(scale: scale, child: child)
          : Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              origin: origin,
              child: child,
            );
    },
    child: child,
  );
}
