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
