import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../buttons/nexo_icon_button.dart';
import '../foundation/nexo_tappable.dart';

/// `Navigation/FocusBar` da lib (`d:Hyv8f`): o foco minimizado, acima da
/// barra de abas. 64 de altura, SurfaceContainerLowest, borda Card/Border,
/// `Shape/LG` e Elevation/2. Ícone `timer` em Primary (`pause` em
/// Icon/Secondary quando pausado), "Foco · 00:24:37" (LabelMedium 600), o
/// plano e os tópicos (LabelSmall) e o botão de pausar ou retomar. Tocar
/// reabre o foco.
class NexoFocusBar extends StatelessWidget {
  const NexoFocusBar({
    super.key,
    required this.time,
    required this.detail,
    required this.paused,
    required this.onOpen,
    required this.onToggle,
  });

  /// "00:24:37".
  final String time;

  /// "Concurso Banco Horizonte · Português".
  final String detail;
  final bool paused;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(context.shape.lg);
    final title = paused ? 'Pausado · $time' : 'Foco · $time';
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: context.elevation.level(2),
      ),
      child: NexoTappable(
        onTap: onOpen,
        borderRadius: radius,
        color: c.surfaceContainerLowest,
        side: BorderSide(color: c.cardBorder),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: height),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: spacing.lg,
              end: spacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  paused ? LucideIcons.pause : LucideIcons.timer,
                  size: 20,
                  color: paused ? c.iconSecondary : c.primary,
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: '$title, $detail. Abrir o foco',
                    onTap: onOpen,
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context
                              .textStyle(NexoTextStyles.labelMediumEmphasis)
                              .copyWith(
                                color: c.onSurface,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall!.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                NexoIconButton(
                  icon: paused ? LucideIcons.play : LucideIcons.pause,
                  tooltip: paused ? 'Retomar' : 'Pausar',
                  color: c.iconDefault,
                  onPressed: onToggle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
