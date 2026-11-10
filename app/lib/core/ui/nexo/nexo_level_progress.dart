import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';
import '../feedback/nexo_linear_progress.dart';

/// `Nexo/LevelProgress` da lib: o nível num círculo de 32
/// (`SecondaryContainer`, número em `OnSecondaryContainer`), "Nível N"
/// (LabelMedium 600), os pontos dentro do nível à direita (LabelSmall) e a
/// barra em `Secondary` (só progresso e conquistas usam Secondary).
///
/// Nível = pontos ÷ 20 + 1; a barra mostra "pontos dentro do nível / 20"
/// (AGENTS.md e contrato §4).
class NexoLevelProgress extends StatelessWidget {
  const NexoLevelProgress({
    super.key,
    required this.level,
    required this.pointsIntoLevel,
    required this.pointsPerLevel,
  });

  final int level;
  final int pointsIntoLevel;
  final int pointsPerLevel;

  static const double badgeSize = 32;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final points = '$pointsIntoLevel / $pointsPerLevel pontos';
    return Semantics(
      container: true,
      label: 'Nível $level, $points',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: badgeSize,
            height: badgeSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.secondaryContainer,
            ),
            child: Text(
              '$level',
              style: context
                  .textStyle(NexoTextStyles.labelMediumEmphasis)
                  .copyWith(color: c.onSecondaryContainer),
            ),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: spacing.sm,
                  children: [
                    Text(
                      'Nível $level',
                      style: context
                          .textStyle(NexoTextStyles.labelMediumEmphasis)
                          .copyWith(color: c.onSurface),
                    ),
                    Text(
                      points,
                      style: textTheme.labelSmall!.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing.sm),
                NexoLinearProgress(
                  value: pointsPerLevel == 0
                      ? 0
                      : pointsIntoLevel / pointsPerLevel,
                  color: c.secondary,
                  semanticsLabel: 'Progresso do nível',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
