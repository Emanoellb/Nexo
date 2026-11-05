import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';
import '../buttons/nexo_button.dart';

/// `Content/EmptyState` da lib: ícone num círculo de 56, título, texto que
/// guia o próximo passo e no máximo uma ação (Secondary).
class NexoEmptyState extends StatelessWidget {
  const NexoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  /// Círculo do ícone (lib: 56).
  static const double iconCircle = 56;

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: spacing.xxl,
        horizontal: spacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Container(
              width: iconCircle,
              height: iconCircle,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: c.iconSecondary),
            ),
          ),
          SizedBox(height: spacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium!.copyWith(color: c.onSurface),
          ),
          SizedBox(height: spacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium!.copyWith(color: c.onSurfaceVariant),
          ),
          if (actionLabel != null) ...[
            SizedBox(height: spacing.md),
            NexoButton.secondary(
              label: actionLabel!,
              leadingIcon: actionIcon,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
