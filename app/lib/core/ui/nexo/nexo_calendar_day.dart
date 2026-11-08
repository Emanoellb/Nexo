import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';

/// `Nexo/CalendarDay` da lib (`d:BmQji`): o número num círculo de 36
/// (`Shape/Full`, LabelMedium), o texto de baixo (horas, "folga", "–") em
/// LabelSmall e, quando há situação, o ícone dela (16) — a cor nunca é o
/// único sinal. Hoje: anel Primary de 2 px. Selecionado: círculo em
/// SurfaceContainer. Fora do período: número em Disabled.
///
/// A célula ocupa a largura da coluna; quem monta a grade garante ≥ 48 de
/// largura (alvo de toque).
class NexoCalendarDay extends StatelessWidget {
  const NexoCalendarDay({
    super.key,
    required this.day,
    required this.below,
    required this.semanticsLabel,
    required this.onTap,
    this.belowColor,
    this.icon,
    this.iconColor,
    this.today = false,
    this.selected = false,
    this.outside = false,
  });

  static const double numberSize = 36;

  final int day;
  final String below;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final Color? belowColor;
  final IconData? icon;
  final Color? iconColor;
  final bool today;
  final bool selected;
  final bool outside;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.shape.md),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: context.sizes.target),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: numberSize,
                  height: numberSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? c.surfaceContainer : null,
                    border: today
                        ? Border.all(color: c.primary, width: 2)
                        : null,
                  ),
                  child: Text(
                    '$day',
                    style: textTheme.labelMedium!.copyWith(
                      color: outside ? c.disabledContent : c.onSurface,
                    ),
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  below,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: textTheme.labelSmall!.copyWith(
                    color: belowColor ?? c.onSurfaceVariant,
                  ),
                ),
                if (icon != null) ...[
                  SizedBox(height: spacing.xs),
                  Icon(icon, size: 16, color: iconColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
