import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';

/// `Nexo/CalendarDay` da lib (`d:BmQji`): o número num círculo de 36
/// (`Shape/Full`, LabelMedium), o texto de baixo (horas, "folga", "–") em
/// LabelSmall e, quando há situação, o ícone dela (16) — a cor nunca é o
/// único sinal. Hoje: anel Primary de 2 px e o número em Primary (Emphasis),
/// nas duas variantes. Selecionado: círculo em SurfaceContainer. Fora do
/// período: número em Disabled. Com [manual]
/// (horas registradas à mão nesse dia), um lápis de 12 em Primary no canto
/// do número.
///
/// Na Agenda ([filledSelection]): o selecionado fica em Primary com o
/// número em OnPrimary, e no lugar do texto de baixo vêm até 3 pontos de
/// carga ([loadDots], só tarefas, separados por XS), em Warning quando
/// [overloaded]. Selecionado, o número fica em OnPrimary (Emphasis). O
/// rótulo do dia da semana fica fora, numa linha própria acima da grade.
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
    this.manual = false,
    this.loadDots,
    this.overloaded = false,
    this.filledSelection = false,
  });

  static const double numberSize = 36;

  /// O mesmo lápis do "Registro manual" na aba Sessões.
  static const IconData manualIcon = LucideIcons.pencil;

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

  /// O dia tem horas registradas à mão ("Registrar horas").
  final bool manual;

  /// Agenda: 0 a 3 pontos de carga no lugar de [below] (`null` = texto).
  final int? loadDots;

  /// Agenda: passou do limite de tarefas do dia (pontos em Warning).
  final bool overloaded;

  /// Agenda: selecionado em Primary (o calendário do plano usa
  /// SurfaceContainer).
  final bool filledSelection;

  /// Lado dos pontos de carga.
  static const double dotSize = 4;

  /// Hoje: Primary em peso Emphasis, nas duas variantes (além do anel).
  /// Agenda, selecionado: OnPrimary em Emphasis (sobre o Primary). O resto:
  /// LabelMedium em OnSurface (decisões do usuário, 09/11/2026).
  TextStyle _numberStyle(BuildContext context) {
    final c = context.nexoColors;
    if (outside) {
      return Theme.of(context).textTheme.labelMedium!
          .copyWith(color: c.disabledContent);
    }
    final emphasis = context.textStyle(NexoTextStyles.labelMediumEmphasis);
    if (filledSelection && selected) {
      return emphasis.copyWith(color: c.onPrimary);
    }
    if (today) return emphasis.copyWith(color: c.primary);
    return Theme.of(context).textTheme.labelMedium!
        .copyWith(color: c.onSurface);
  }

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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: numberSize,
                      height: numberSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? (filledSelection ? c.primary : c.surfaceContainer)
                            : null,
                        border: today
                            ? Border.all(color: c.primary, width: 2)
                            : null,
                      ),
                      child: Text('$day', style: _numberStyle(context)),
                    ),
                    if (manual)
                      PositionedDirectional(
                        top: -spacing.xs,
                        end: -spacing.xs,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.surface,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(manualIcon, size: 12, color: c.primary),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: spacing.xs),
                if (loadDots != null)
                  SizedBox(
                    height: dotSize,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < loadDots!.clamp(0, 3); i++) ...[
                          if (i > 0) SizedBox(width: spacing.xs),
                          Container(
                            width: dotSize,
                            height: dotSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: overloaded
                                  ? c.warning
                                  : c.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
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
