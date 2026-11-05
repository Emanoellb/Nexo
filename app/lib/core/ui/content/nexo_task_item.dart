import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
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
class NexoDeadline extends StatelessWidget {
  const NexoDeadline({
    super.key,
    required this.text,
    required this.semanticsLabel,
    this.tone = NexoDeadlineTone.normal,
  });

  final String text;
  final String semanticsLabel;
  final NexoDeadlineTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final iconColor = switch (tone) {
      NexoDeadlineTone.normal => c.iconSecondary,
      NexoDeadlineTone.today => c.iconSelected,
      NexoDeadlineTone.overdue => c.iconError,
    };
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.clock3, size: 16, color: iconColor),
          SizedBox(width: context.spacing.xs),
          // Encolhe e quebra em telas estreitas ou com fonte ampliada.
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall!
                  .copyWith(color: c.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// `Content/TaskItem` da lib: Checkbox (conclui), título (BodyLarge),
/// linha de meta (disciplina + prazo) e a bandeira de prioridade alta
/// (`Nexo/Priority`, só a Alta aparece na lista). Sem container próprio:
/// vive numa lista com divisores.
class NexoTaskItem extends StatelessWidget {
  const NexoTaskItem({
    super.key,
    required this.title,
    required this.completed,
    required this.onCompletedChanged,
    this.subject,
    this.deadline,
    this.highPriority = false,
  });

  final String title;
  final bool completed;
  final ValueChanged<bool>? onCompletedChanged;

  /// Nome da disciplina (ícone `book-open`).
  final String? subject;
  final NexoDeadline? deadline;
  final bool highPriority;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final small = textTheme.labelSmall!.copyWith(color: c.onSurfaceVariant);
    final hasMeta = subject != null || deadline != null;

    return Padding(
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.bookOpen,
                              size: 16,
                              color: c.iconSecondary,
                            ),
                            SizedBox(width: spacing.xs),
                            Flexible(
                              child: Text(
                                subject!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: small,
                              ),
                            ),
                          ],
                        ),
                      ?deadline,
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (highPriority) ...[
            SizedBox(width: spacing.xs),
            Semantics(
              label: 'Prioridade alta',
              child: Icon(LucideIcons.flag, size: 20, color: c.iconWarning),
            ),
          ],
        ],
      ),
    );
  }
}
