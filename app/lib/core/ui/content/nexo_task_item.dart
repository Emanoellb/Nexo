import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';
import '../selection/nexo_checkbox.dart';

/// Tom do `Nexo/Deadline`: a cor nunca é o único sinal ("Atrasada" vem
/// escrito no texto).
enum NexoDeadlineTone {
  /// Data comum.
  normal,

  /// Hoje, numa lista com datas misturadas.
  today,

  /// Atrasada: ícone de erro + a palavra "Atrasada".
  overdue,
}

/// `Nexo/Deadline` da lib: relógio de 16 + texto curto ("Hoje · 18:00",
/// "Sex · 19:00", "Atrasada · ontem, 23:59"). O leitor de tela recebe
/// [semanticsLabel] (ex.: "Prazo: hoje às 18:00").
///
/// Sem o relógio ([showIcon] falso) na lista enxuta do `Content/TaskItem`
/// (design da Tarefa, 07/11/2026).
class NexoDeadline extends StatelessWidget {
  const NexoDeadline({
    super.key,
    required this.text,
    required this.semanticsLabel,
    this.tone = NexoDeadlineTone.normal,
    this.showIcon = true,
  });

  final String text;
  final String semanticsLabel;
  final NexoDeadlineTone tone;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    // Ícone e texto no mesmo tom (design de 05/11/2026): "Hoje" em Primary,
    // "Atrasada" em Error; o texto "Atrasada" garante que a cor não é o
    // único sinal.
    final (iconColor, textColor) = switch (tone) {
      NexoDeadlineTone.normal => (c.iconSecondary, c.onSurfaceVariant),
      NexoDeadlineTone.today => (c.iconSelected, c.primary),
      NexoDeadlineTone.overdue => (c.iconError, c.error),
    };
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(LucideIcons.clock3, size: 16, color: iconColor),
            SizedBox(width: context.spacing.xs),
          ],
          // Encolhe e quebra em telas estreitas ou com fonte ampliada.
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall!
                  .copyWith(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// `Content/TaskItem` da lib, na lista enxuta (design da Tarefa,
/// 07/11/2026): Checkbox (conclui), título (BodyLarge) e a linha de meta
/// só em texto (disciplina e prazo, com "Atrasada" por extenso). Sem ícone
/// de disciplina, relógio, bandeira de prioridade ou ícone da situação:
/// prioridade e situação ficam só no detalhe. Sem container próprio: vive
/// numa lista com divisores.
///
/// [onTap] abre a tarefa; [onLongPress] abre o menu de ações (as mesmas do
/// deslizar). O Checkbox continua com o próprio toque.
class NexoTaskItem extends StatelessWidget {
  const NexoTaskItem({
    super.key,
    required this.title,
    required this.completed,
    required this.onCompletedChanged,
    this.subject,
    this.deadline,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final bool completed;
  final ValueChanged<bool>? onCompletedChanged;

  /// Nome da disciplina, só em texto.
  final String? subject;

  /// Prazo; a lista o mostra sem o relógio.
  final NexoDeadline? deadline;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final small = textTheme.labelSmall!.copyWith(color: c.onSurfaceVariant);
    final hasMeta = subject != null || deadline != null;

    final row = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        spacing.xs,
        spacing.sm,
        spacing.lg,
        spacing.sm,
      ),
      child: Row(
        children: [
          NexoCheckbox(
            value: completed,
            onChanged: onCompletedChanged == null
                ? null
                : (value) {
                    // Vibração leve só ao concluir (decisão do usuário,
                    // 05/11/2026); o Android segue a configuração de
                    // vibração ao toque do sistema.
                    if (value) HapticFeedback.lightImpact();
                    onCompletedChanged!(value);
                  },
            semanticLabel: completed ? 'Concluída: $title' : 'Concluir: $title',
          ),
          SizedBox(width: spacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge!.copyWith(
                    color: completed ? c.onSurfaceVariant : c.onSurface,
                    decoration: completed ? TextDecoration.lineThrough : null,
                    decorationColor: c.onSurfaceVariant,
                  ),
                ),
                if (hasMeta) ...[
                  SizedBox(height: spacing.xs),
                  Wrap(
                    spacing: spacing.md,
                    runSpacing: spacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (subject != null)
                        Text(
                          subject!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: small,
                        ),
                      if (deadline case final d?)
                        NexoDeadline(
                          text: d.text,
                          semanticsLabel: d.semanticsLabel,
                          tone: d.tone,
                          showIcon: false,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null && onLongPress == null) return row;
    return NexoTappable(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.zero,
      child: row,
    );
  }
}
