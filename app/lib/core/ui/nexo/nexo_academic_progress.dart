import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';
import '../feedback/nexo_linear_progress.dart';

/// `Nexo/AcademicProgress` da lib: progresso de uma disciplina em entregas
/// concluídas (não nota). Título (LabelMedium 600) + contagem, barra
/// Secondary e a próxima entrega (Error se atrasada; o texto diz
/// "atrasada", a cor não é o único sinal).
class NexoAcademicProgress extends StatelessWidget {
  const NexoAcademicProgress({
    super.key,
    required this.title,
    required this.done,
    required this.total,
    required this.nextDelivery,
    this.nextOverdue = false,
  });

  final String title;
  final int done;
  final int total;

  /// "Próxima: Lista 3 · qui"; `null` esconde a linha.
  final String? nextDelivery;
  final bool nextOverdue;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final count = '$done de $total ${total == 1 ? 'entrega' : 'entregas'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Lib: título à esquerda e contagem à direita; com fonte grande, a
        // contagem desce para a linha de baixo.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: spacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              title,
              style: context
                  .textStyle(NexoTextStyles.labelMediumEmphasis)
                  .copyWith(color: c.onSurface),
            ),
            Text(
              count,
              style: textTheme.labelSmall!.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ),
        SizedBox(height: spacing.sm),
        NexoLinearProgress(
          value: total == 0 ? 0 : done / total,
          semanticsLabel: title,
          semanticsValue: count,
        ),
        if (nextDelivery != null) ...[
          SizedBox(height: spacing.sm),
          Text(
            nextDelivery!,
            style: textTheme.labelSmall!.copyWith(
              color: nextOverdue ? c.error : c.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
