import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../buttons/nexo_button.dart';

/// `Feedback/Dialog` da lib: 312 de largura, padding XL, gap LG,
/// SurfaceContainerLowest, Shape/LG, Elevation/3, centralizado sobre o
/// Scrim. Ícone opcional, título em pergunta (HeadingMedium), texto com a
/// consequência e as ações "Cancelar" (Tertiary) + verbo (Primary, ou
/// Destructive/High com [destructive]: ícone padrão em Icon/Error).
///
/// Devolve `true` só na confirmação. Fecha com Cancelar, voltar ou toque no
/// fundo (`false`/`null`).
Future<bool> showNexoDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  IconData? icon,
  Color? iconColor,
  bool destructive = false,
}) async {
  final c = context.nexoColors;
  final motion = context.motion;
  final duration = MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : motion.medium;
  final confirmed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: cancelLabel,
    barrierColor: c.scrim,
    transitionDuration: duration,
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: motion.enter),
      child: child,
    ),
    pageBuilder: (dialogContext, _, _) => NexoDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
      iconColor: iconColor ?? (destructive ? c.iconError : null),
      destructive: destructive,
      onCancel: () => Navigator.of(dialogContext).pop(false),
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  return confirmed ?? false;
}

/// "Descartar alterações?" ao sair de um formulário com mudanças (Tarefa
/// 12, Criar e Editar plano): "Continuar editando" (Tertiary) e "Descartar"
/// (Destructive/High). `true` = descartar.
Future<bool> showNexoDiscardDialog(
  BuildContext context, {
  required String message,
}) => showNexoDialog(
  context,
  title: 'Descartar alterações?',
  message: message,
  confirmLabel: 'Descartar',
  cancelLabel: 'Continuar editando',
  icon: LucideIcons.circleAlert,
  destructive: true,
);

class NexoDialog extends StatelessWidget {
  const NexoDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onCancel,
    required this.onConfirm,
    this.icon,
    this.iconColor,
    this.destructive = false,
  });

  static const double width = 312;

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final IconData? icon;
  final Color? iconColor;

  /// Confirmação com `Actions/Button/Destructive/High` (ex.: excluir).
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final screen = MediaQuery.sizeOf(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: title,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: width.clamp(0, screen.width - spacing.lg * 2),
              padding: EdgeInsets.all(spacing.xl),
              decoration: BoxDecoration(
                color: c.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(context.shape.lg),
                boxShadow: context.elevation.level(3),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      ExcludeSemantics(
                        child: Icon(
                          icon,
                          size: 24,
                          color: iconColor ?? c.iconDefault,
                        ),
                      ),
                      SizedBox(height: spacing.lg),
                    ],
                    Text(
                      title,
                      style: textTheme.headlineSmall!.copyWith(
                        color: c.onSurface,
                      ),
                    ),
                    SizedBox(height: spacing.sm),
                    Text(
                      message,
                      style: textTheme.bodyMedium!.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: spacing.lg),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: spacing.sm,
                      runSpacing: spacing.sm,
                      children: [
                        NexoButton.tertiary(
                          label: cancelLabel,
                          onPressed: onCancel,
                        ),
                        if (destructive)
                          NexoButton.destructiveHigh(
                            label: confirmLabel,
                            onPressed: onConfirm,
                          )
                        else
                          NexoButton.primary(
                            label: confirmLabel,
                            onPressed: onConfirm,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
