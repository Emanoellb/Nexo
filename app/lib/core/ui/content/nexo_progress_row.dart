import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../feedback/nexo_linear_progress.dart';
import '../foundation/nexo_tappable.dart';
import '../menu/nexo_menu.dart';

/// Linha de lista com progresso (Planos 02 e 09, Disciplinas): nome
/// (LabelMedium 600) e valor à direita ("Dia 23 de 300", "Até jul/2027",
/// "3 de 5 entregas"), a barra Secondary opcional e a linha de baixo
/// opcional (em Error com [lineIsError]; o texto diz o motivo, a cor não é
/// o único sinal), com o chevron. Padding LG. Toque abre;
/// toque longo (opcional) recebe o retângulo da linha para ancorar um menu.
/// Lida como um só botão pelo leitor de tela.
class NexoProgressRow extends StatelessWidget {
  const NexoProgressRow({
    super.key,
    required this.title,
    required this.value,
    required this.onTap,
    this.line,
    this.lineIsError = false,
    this.progress,
    this.progressSemantics,
    this.onLongPress,
    this.longPressHint,
  });

  final String title;
  final String value;
  final String? line;
  final bool lineIsError;
  final VoidCallback onTap;

  /// 0–1; `null` esconde a barra.
  final double? progress;
  final String? progressSemantics;
  final ValueChanged<Rect>? onLongPress;

  /// O que o toque longo faz, para o leitor de tela (ex.: "Ações do plano").
  final String? longPressHint;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final small = Theme.of(context).textTheme.labelSmall!
        .copyWith(color: c.onSurfaceVariant);

    return Builder(
      builder: (rowContext) {
        // Onde o dedo tocou (para o menu nascer ali).
        Offset? lastDown;
        final longPress = onLongPress == null
            ? null
            : () {
                // O menu nasce no ponto tocado; sem toque (leitor de tela),
                // no centro da linha.
                final box = rowContext.findRenderObject()! as RenderBox;
                final point =
                    lastDown ?? box.localToGlobal(box.size.center(Offset.zero));
                onLongPress!(anchorAt(point));
              };
        return Semantics(
          button: true,
          label: [title, value, ?line].join(', '),
          onTap: onTap,
          onLongPress: longPress,
          onLongPressHint: longPress == null ? null : longPressHint,
          excludeSemantics: true,
          child: Listener(
            onPointerDown: (e) => lastDown = e.position,
            child: NexoTappable(
              onTap: onTap,
              onLongPress: longPress,
              borderRadius: BorderRadius.zero,
              child: Padding(
                padding: EdgeInsets.all(spacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: spacing.sm,
                            children: [
                              Text(
                                title,
                                style: context
                                    .textStyle(
                                      NexoTextStyles.labelMediumEmphasis,
                                    )
                                    .copyWith(color: c.onSurface),
                              ),
                              Text(value, style: small),
                            ],
                          ),
                          if (progress != null) ...[
                            SizedBox(height: spacing.sm),
                            NexoLinearProgress(
                              value: progress!,
                              semanticsLabel: title,
                              semanticsValue: progressSemantics,
                            ),
                          ],
                          if (line != null) ...[
                            SizedBox(height: spacing.sm),
                            Text(
                              line!,
                              style: lineIsError
                                  ? small.copyWith(color: c.error)
                                  : small,
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: spacing.md),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 20,
                      color: c.iconSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
