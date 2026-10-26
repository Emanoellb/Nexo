import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../buttons/nexo_button.dart';

enum NexoAlertTone { info, success, warning, error }

/// `Feedback/Alert` da lib: aviso inline e persistente na tela.
/// Fundo `<Tom>Container`, texto `On<Tom>Container`, ícone `Icon/<Tom>`.
/// Ícone e título acompanham a cor: a cor nunca é o único sinal.
class NexoAlert extends StatelessWidget {
  const NexoAlert({
    super.key,
    required this.tone,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final NexoAlertTone tone;
  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;

    final (container, onContainer, iconColor, icon) = switch (tone) {
      NexoAlertTone.info => (
        c.infoContainer,
        c.onInfoContainer,
        c.iconInfo,
        LucideIcons.info,
      ),
      NexoAlertTone.success => (
        c.successContainer,
        c.onSuccessContainer,
        c.iconSuccess,
        LucideIcons.circleCheck,
      ),
      NexoAlertTone.warning => (
        c.warningContainer,
        c.onWarningContainer,
        c.iconWarning,
        LucideIcons.triangleAlert,
      ),
      NexoAlertTone.error => (
        c.errorContainer,
        c.onErrorContainer,
        c.iconError,
        LucideIcons.circleX,
      ),
    };

    return Semantics(
      container: true,
      liveRegion: tone == NexoAlertTone.error,
      child: Container(
        padding: EdgeInsets.all(spacing.lg),
        decoration: BoxDecoration(
          color: container,
          borderRadius: BorderRadius.circular(context.shape.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 20, color: iconColor)),
            SizedBox(width: spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: textTheme.labelLarge!.copyWith(color: onContainer),
                    ),
                    SizedBox(height: spacing.xs),
                  ],
                  Text(
                    message,
                    style: textTheme.bodyMedium!.copyWith(color: onContainer),
                  ),
                  if (actionLabel != null) ...[
                    SizedBox(height: spacing.xs),
                    NexoButton.tertiary(
                      label: actionLabel!,
                      onPressed: onAction,
                      contentColor: onContainer,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
