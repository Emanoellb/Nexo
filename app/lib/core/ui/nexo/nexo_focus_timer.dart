import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';
import '../feedback/nexo_linear_progress.dart';

/// "01:24:37" a partir de uma duração.
String formatClock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final s = d.inSeconds;
  return '${two(s ~/ 3600)}:${two(s % 3600 ~/ 60)}:${two(s % 60)}';
}

/// `Nexo/FocusTimer` da lib (`d:oPDYL`): rótulo ("Sessão de foco" ou
/// "Pausado há 3 min", LabelSmall 600), o tempo em `Typography/DisplayTimer`
/// (OnSurfaceVariant quando pausado), o total do dia (BodyMedium) e a barra
/// do dia (Secondary, 240 de largura). MD entre as partes.
///
/// O leitor de tela não ouve o tempo a cada segundo: o nó lê o rótulo, o
/// tempo e o total quando a pessoa chega nele (spec do Foco).
class NexoFocusTimer extends StatelessWidget {
  const NexoFocusTimer({
    super.key,
    required this.label,
    required this.elapsed,
    required this.dayTotal,
    required this.dayProgress,
    this.paused = false,
  });

  final String label;
  final Duration elapsed;

  /// "Hoje: 1h 09min de 1h 30min".
  final String dayTotal;

  /// 0–1; `null` esconde a barra.
  final double? dayProgress;
  final bool paused;

  static const double barWidth = 240;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final time = formatClock(elapsed);
    return Semantics(
      container: true,
      label: '$label, $time, $dayTotal',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: context
                .textStyle(NexoTextStyles.labelSmallEmphasis)
                .copyWith(color: c.onSurfaceVariant),
          ),
          SizedBox(height: spacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              time,
              style: context
                  .textStyle(NexoTextStyles.displayTimer)
                  .copyWith(
                    color: paused ? c.onSurfaceVariant : c.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
          SizedBox(height: spacing.md),
          Text(
            dayTotal,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium!.copyWith(color: c.onSurfaceVariant),
          ),
          if (dayProgress != null) ...[
            SizedBox(height: spacing.md),
            SizedBox(
              width: barWidth,
              child: NexoLinearProgress(
                value: dayProgress!.clamp(0, 1),
                semanticsLabel: 'Progresso de hoje',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
