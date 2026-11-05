import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../buttons/nexo_icon_button.dart';
import '../foundation/nexo_tappable.dart';

/// `Feedback/NotificationPanel` da lib (aprovado em 04/11/2026): cartão de
/// 320 com uma seta de balão (20 × 10) apontando para o centro do sino.
/// Cabeçalho com "Marcar todas como lidas" e Fechar; lista de até 400 de
/// altura, com rolagem e Divider entre os avisos; estado vazio.
class NexoNotificationPanel extends StatelessWidget {
  const NexoNotificationPanel({
    super.key,
    required this.items,
    required this.onMarkAllRead,
    required this.onClose,
    this.arrowCenter,
    this.width = defaultWidth,
  });

  static const double defaultWidth = 320;
  static const double maxListHeight = 400;
  static const Size arrowSize = Size(20, 10);

  /// Avisos já ordenados (não lidos primeiro).
  final List<Widget> items;

  /// `null` desabilita o botão (nada a marcar).
  final VoidCallback? onMarkAllRead;
  final VoidCallback onClose;

  /// Distância da borda esquerda do painel até o centro da seta. Padrão: o
  /// sino no canto direito do topo das abas.
  final double? arrowCenter;

  /// 320; menos em telas estreitas.
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(context.shape.lg);

    Widget divider() => Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      child: Divider(height: 1, thickness: 1, color: c.outlineVariant),
    );

    final card = Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: radius,
        border: Border.all(color: c.cardBorder),
        boxShadow: context.elevation.level(3),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.lg,
                spacing.xs,
                spacing.xs,
                spacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Notificações',
                            style: textTheme.titleMedium!.copyWith(
                              color: c.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          'Últimos 30 dias',
                          style: textTheme.labelSmall!.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  NexoIconButton(
                    icon: LucideIcons.checkCheck,
                    tooltip: 'Marcar todas como lidas',
                    color: c.iconDefault,
                    onPressed: onMarkAllRead,
                  ),
                  NexoIconButton(
                    icon: LucideIcons.x,
                    tooltip: 'Fechar',
                    color: c.iconDefault,
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            divider(),
            if (items.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: spacing.xxl,
                  horizontal: spacing.lg,
                ),
                child: Column(
                  children: [
                    Icon(LucideIcons.bell, size: 24, color: c.iconSecondary),
                    SizedBox(height: spacing.sm),
                    Text(
                      'Nenhuma notificação recente',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium!.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: maxListHeight),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  itemBuilder: (_, i) => items[i],
                  separatorBuilder: (_, _) => divider(),
                ),
              ),
          ],
        ),
      ),
    );

    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(top: arrowSize.height),
            child: card,
          ),
          // A seta sobrepõe 1 px a borda do cartão, para a linha ficar
          // contínua.
          Positioned(
            top: 1,
            left: (arrowCenter ?? width - 44) - arrowSize.width / 2,
            child: CustomPaint(
              size: arrowSize,
              painter: _ArrowPainter(
                fill: c.surfaceContainerLowest,
                stroke: c.cardBorder,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final tip = Offset(size.width / 2, 0);
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    // Só os lados inclinados: a base se funde ao cartão.
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(size.width, size.height),
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.fill != fill || old.stroke != stroke;
}

/// Abre o painel preso logo abaixo de [anchor] (o sino), alinhado à direita
/// (16 px), por cima do conteúdo e sem escurecer a tela. Fecha pelo voltar ou
/// com toque fora; o foco volta a quem o abriu.
Future<void> showNexoNotificationPanel(
  BuildContext context, {
  required Rect anchor,
  required Widget Function(
    BuildContext context,
    double width,
    double arrowCenter,
  )
  builder,
}) {
  final c = context.nexoColors;
  final spacing = context.spacing;
  final screen = MediaQuery.sizeOf(context);
  final width = (screen.width - spacing.lg * 2).clamp(
    0.0,
    NexoNotificationPanel.defaultWidth,
  );
  final left = screen.width - spacing.lg - width;
  final duration = MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : context.motion.short;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar notificações',
    // Sem escurecer a tela.
    barrierColor: c.scrim.withValues(alpha: 0),
    transitionDuration: duration,
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (context, _, _) => Stack(
      children: [
        Positioned(
          top: anchor.bottom,
          right: spacing.lg,
          child: Material(
            type: MaterialType.transparency,
            child: builder(context, width, anchor.center.dx - left),
          ),
        ),
      ],
    ),
  );
}

/// `Content/NotificationItem` da lib: círculo de 32 com o ícone do tipo,
/// título, texto (2 linhas) e tempo. Não lido: ponto Primary, título 600,
/// fundo SurfaceContainerLow e círculo com borda.
class NexoNotificationItem extends StatelessWidget {
  const NexoNotificationItem({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
    required this.unread,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String time;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final small = Theme.of(context).textTheme.labelSmall!;
    final titleStyle =
        (unread ? NexoTextStyles.labelSmallEmphasis : NexoTextStyles.labelSmall)
            .copyWith(color: c.onSurface);

    return Semantics(
      button: true,
      label: '${unread ? 'Não lida. ' : ''}$title. $body. $time',
      onTap: onTap,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        color: unread ? c.surfaceContainerLow : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: spacing.sm,
            horizontal: spacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: unread ? c.surfaceContainerLowest : c.surfaceContainer,
                  shape: BoxShape.circle,
                  border: unread ? Border.all(color: c.cardBorder) : null,
                ),
                child: Icon(icon, size: 16, color: c.iconDefault),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                        ),
                        SizedBox(width: spacing.sm),
                        Text(
                          time,
                          style: small.copyWith(color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                    // 2 px: valor da lib, sem token (registrado para a lib).
                    const SizedBox(height: 2),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: small.copyWith(color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.sm),
              SizedBox(
                width: 8,
                height: 16,
                child: unread
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
