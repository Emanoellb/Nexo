import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../buttons/nexo_button.dart';
import '../content/nexo_card.dart';
import '../feedback/nexo_linear_progress.dart';

/// `Nexo/PlanCard` da lib: o plano principal no topo do Início.
///
/// "PLANO DE AÇÃO" + "Dia X de N", título, progresso do dia (texto à
/// esquerda, detalhe à direita e a barra), sequência e ações. Quem usa monta
/// as ações: Focar (Primary) domina e Finalizar o dia é Tertiary; depois do
/// dia cumprido, "Estudar mais" (Secondary). A barra é Secondary no
/// andamento e Success no dia cumprido ([completed]).
class NexoPlanCard extends StatelessWidget {
  const NexoPlanCard({
    super.key,
    required this.dayLabel,
    this.title,
    required this.progressLabel,
    this.progressDetail,
    required this.progress,
    this.streakLabel,
    required this.primaryAction,
    this.tertiaryLabel,
    this.onTertiary,
    this.completed = false,
    this.progressSemantics,
    this.onOpen,
  });

  /// "Dia 23 de 300".
  final String dayLabel;

  /// Nome do plano, com "PLANO DE AÇÃO" acima. `null` esconde os dois: o
  /// cartão "Hoje" da Visão geral, onde o nome já está no topo da tela.
  final String? title;

  /// "Hoje · 1h 10min de 1h 30min" ou "Dia cumprido · 1h 35min".
  final String progressLabel;

  /// "Faltam 20 min", "+15 min da meta"… `null`: sem detalhe (arquivado,
  /// encerrado).
  final String? progressDetail;

  /// 0–1. `null` esconde a barra (ex.: dia de folga).
  final double? progress;
  final bool completed;

  /// Valor lido pelo leitor de tela na barra.
  final String? progressSemantics;

  /// "12 dias seguidos" ou "Comece sua sequência hoje". `null` esconde a
  /// linha (plano arquivado ou encerrado).
  final String? streakLabel;

  /// Ação principal, que ocupa o espaço que sobra (Focar ou Estudar mais),
  /// já montada com `expand: true`.
  final Widget primaryAction;

  /// Ação Tertiary ao lado ("Finalizar o dia"). Quando não cabe ao lado sem
  /// espremer a principal (fonte ampliada, tela estreita), vai para baixo.
  final String? tertiaryLabel;
  final VoidCallback? onTertiary;

  /// Tocar no cartão (fora dos botões) abre o detalhe do plano. `null` no
  /// próprio detalhe.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final small = textTheme.labelSmall!.copyWith(color: c.onSurfaceVariant);

    return NexoCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quebra a linha com fonte grande, em vez de estourar.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: spacing.sm,
            runSpacing: spacing.xs,
            children: [
              if (title != null)
                Text(
                  'PLANO DE AÇÃO',
                  style: context
                      .textStyle(NexoTextStyles.labelSmallEmphasis)
                      .copyWith(color: c.primary),
                ),
              Text(dayLabel, style: small),
            ],
          ),
          SizedBox(height: spacing.md),
          if (title != null) ...[
            Semantics(
              header: true,
              child: Text(
                title!,
                style: textTheme.titleLarge!.copyWith(color: c.onSurface),
              ),
            ),
            SizedBox(height: spacing.md),
          ],
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: spacing.sm,
            runSpacing: spacing.xs,
            children: [
              Text(
                progressLabel,
                style: context
                    .textStyle(NexoTextStyles.labelMediumEmphasis)
                    .copyWith(color: c.onSurface),
              ),
              if (progressDetail != null) Text(progressDetail!, style: small),
            ],
          ),
          if (progress != null) ...[
            SizedBox(height: spacing.sm),
            NexoLinearProgress(
              value: progress!,
              color: completed ? c.success : c.secondary,
              semanticsLabel: 'Progresso de hoje',
              semanticsValue: progressSemantics,
            ),
          ],
          if (streakLabel != null) ...[
            SizedBox(height: spacing.md),
            Row(
              children: [
                Icon(LucideIcons.flame, size: 16, color: c.secondary),
                SizedBox(width: spacing.xs),
                Flexible(child: Text(streakLabel!, style: small)),
              ],
            ),
          ],
          SizedBox(height: spacing.md),
          _actions(context),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final label = tertiaryLabel;
    if (label == null) return primaryAction;
    final spacing = context.spacing;
    final tertiary = NexoButton.tertiary(label: label, onPressed: onTertiary);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Largura do Tertiary: rótulo (estilo do botão, com a escala de
        // fonte) + padding LG dos dois lados.
        final painter = TextPainter(
          text: TextSpan(
            text: label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final tertiaryWidth = painter.width + spacing.lg * 2;
        painter.dispose();
        // A principal precisa de pelo menos dois alvos de largura.
        final fits =
            constraints.maxWidth - tertiaryWidth - spacing.sm >=
            context.sizes.target * 2;
        if (fits) {
          return Row(
            children: [
              Expanded(child: primaryAction),
              SizedBox(width: spacing.sm),
              tertiary,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            primaryAction,
            SizedBox(height: spacing.sm),
            tertiary,
          ],
        );
      },
    );
  }
}
