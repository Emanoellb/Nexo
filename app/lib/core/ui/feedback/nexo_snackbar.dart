import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../buttons/nexo_button.dart';
import '../buttons/nexo_icon_button.dart';

/// Ícone de status do Snackbar. A cor nunca é o único sinal: o texto da
/// mensagem diz o que aconteceu.
enum NexoSnackbarTone { none, success, error, info }

/// `Feedback/Snackbar` da lib: superfície clara com borda, Elevation/3,
/// ícone de status opcional, mensagem, ação (Tertiary) e fechar opcionais.
class NexoSnackbar extends StatelessWidget {
  const NexoSnackbar({
    super.key,
    required this.message,
    this.tone = NexoSnackbarTone.none,
    this.actionLabel,
    this.onAction,
    this.onClose,
  });

  final String message;
  final NexoSnackbarTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;

    final (IconData, Color)? status = switch (tone) {
      NexoSnackbarTone.none => null,
      NexoSnackbarTone.success => (LucideIcons.circleCheck, c.iconSuccess),
      NexoSnackbarTone.error => (LucideIcons.circleX, c.iconError),
      NexoSnackbarTone.info => (LucideIcons.bell, c.iconSecondary),
    };

    return Container(
      constraints: BoxConstraints(minHeight: context.sizes.target),
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        spacing.xs,
        spacing.xs,
        spacing.xs,
      ),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(context.shape.md),
        border: Border.all(color: c.cardBorder),
        boxShadow: context.elevation.level(3),
      ),
      child: Row(
        children: [
          if (status != null)
            Padding(
              padding: EdgeInsets.only(right: spacing.sm),
              child: Icon(status.$1, size: 20, color: status.$2),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.sm),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium!
                    .copyWith(color: c.onSurface),
              ),
            ),
          ),
          if (actionLabel != null)
            NexoButton.tertiary(label: actionLabel!, onPressed: onAction),
          if (onClose != null)
            NexoIconButton(
              icon: LucideIcons.x,
              tooltip: 'Fechar',
              iconSize: 20,
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}

/// Mostra um [NexoSnackbar] flutuante no rodapé. O SnackBar do Flutter já
/// anuncia a mensagem para o leitor de tela.
///
/// - Com ação ("Desfazer") e leitor de tela ativo, NÃO some sozinha (M3,
///   WCAG 2.2.1): fica até a pessoa agir ou fechar, e ganha o botão
///   Fechar. Sem leitor de tela, some em [duration] (4 s, do design).
/// - [queue]: entra depois da atual, em vez de substituí-la (ex.: a
///   confirmação de "criar" não apaga "Primeiros passos concluídos.").
/// - [clearQueue]: tira a atual e as da fila e aparece já (ex.: "Primeiros
///   passos concluídos.", que não pode ficar atrás de outras).
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showNexoSnackbar(
  BuildContext context, {
  required String message,
  NexoSnackbarTone tone = NexoSnackbarTone.none,
  String? actionLabel,
  VoidCallback? onAction,
  bool showClose = false,
  bool queue = false,
  bool clearQueue = false,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.of(context);
  if (clearQueue) {
    messenger.clearSnackBars();
  } else if (!queue) {
    messenger.hideCurrentSnackBar();
  }
  final persist =
      onAction != null && MediaQuery.accessibleNavigationOf(context);
  return messenger.showSnackBar(
    SnackBar(
      // Fundo do SnackBar invisível: a superfície é a do NexoSnackbar. Sem
      // papel "transparente" na lib, usa o mesmo token com alfa 0.
      backgroundColor: context.nexoColors.surfaceContainerLowest.withValues(
        alpha: 0,
      ),
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      duration: duration,
      persist: persist,
      margin: EdgeInsets.fromLTRB(
        context.spacing.lg,
        0,
        context.spacing.lg,
        context.spacing.lg,
      ),
      content: NexoSnackbar(
        message: message,
        tone: tone,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                messenger.hideCurrentSnackBar(
                  reason: SnackBarClosedReason.action,
                );
                onAction();
              },
        onClose: showClose || persist ? messenger.hideCurrentSnackBar : null,
      ),
    ),
  );
}
