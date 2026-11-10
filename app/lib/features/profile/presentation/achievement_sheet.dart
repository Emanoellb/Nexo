import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../progress/application/achievements_providers.dart';

const _months = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// "Conquistada em 3 de novembro de 2026".
String earnedText(DateTime at) {
  final d = at.toLocal();
  return 'Conquistada em ${d.day} de ${_months[d.month - 1]} de ${d.year}';
}

/// Detalhe da medalha (Perfil 03 e 04): o título, o círculo de 72, o
/// critério e a data (conquistada) ou quanto falta (bloqueada), com Fechar.
Future<void> showAchievementSheet(
  BuildContext context,
  AchievementStatus medal,
) => showNexoBottomSheet<void>(
  context,
  title: medal.def.title,
  builder: (sheetContext) {
    final c = sheetContext.nexoColors;
    final spacing = sheetContext.spacing;
    final textTheme = Theme.of(sheetContext).textTheme;
    final earned = medal.earnedAt;
    final small = earned != null ? earnedText(earned) : medal.missing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: earned != null
                    ? c.secondaryContainer
                    : c.surfaceContainerHigh,
              ),
              child: Icon(
                earned != null ? medal.def.icon : LucideIcons.lock,
                size: 32,
                color: earned != null ? c.secondary : c.iconDisabled,
                semanticLabel: earned != null ? 'Conquistada' : 'Bloqueada',
              ),
            ),
          ),
          SizedBox(height: spacing.lg),
          Text(
            medal.def.criterion,
            style: textTheme.bodyMedium!.copyWith(color: c.onSurface),
          ),
          if (small != null) ...[
            SizedBox(height: spacing.xs),
            Text(
              small,
              style: textTheme.labelSmall!.copyWith(color: c.onSurfaceVariant),
            ),
          ],
          SizedBox(height: spacing.lg),
          NexoButton.primary(
            label: 'Fechar',
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
          SizedBox(height: spacing.lg),
        ],
      ),
    );
  },
);
