import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';

/// `Nexo/PlanStat` da lib (`d:u5ZHu`): número grande (HeadingMedium),
/// rótulo e detalhe (Secondary) num cartão Card/Secondary com `Shape/MD`
/// e padding LG. Lido como um só texto pelo leitor de tela.
class NexoPlanStat extends StatelessWidget {
  const NexoPlanStat({
    super.key,
    required this.value,
    required this.label,
    this.detail,
  });

  final String value;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: [value, label, ?detail].join(', '),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.all(spacing.lg),
        decoration: BoxDecoration(
          color: c.cardSecondary,
          borderRadius: BorderRadius.circular(context.shape.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              value,
              style: textTheme.headlineMedium!.copyWith(color: c.onSurface),
            ),
            SizedBox(height: spacing.xs),
            Text(
              label,
              style: textTheme.labelSmall!.copyWith(color: c.onSurfaceVariant),
            ),
            if (detail != null) ...[
              SizedBox(height: spacing.xs),
              Text(
                detail!,
                style: textTheme.labelSmall!.copyWith(color: c.secondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Situação de um dia do plano (`Nexo/PlanDayStatus`): o ícone e a cor
/// junto com o texto (a cor nunca é o único sinal).
enum NexoDayTone {
  met(LucideIcons.circleCheck, 'Cumprido na meta'),
  short(LucideIcons.circleMinus, 'Com horas a menos'),
  over(LucideIcons.circlePlus, 'Com horas a mais'),
  missed(LucideIcons.circleX, 'Não cumprido'),
  off(LucideIcons.moon, 'Folga ou pausa');

  const NexoDayTone(this.icon, this.label);

  final IconData icon;
  final String label;

  /// Cores do design (Planos 2c): cumprido Icon/Success, a mais Secondary,
  /// a menos Icon/Warning, não cumprido Icon/Error, folga Icon/Secondary.
  Color color(NexoColors c) => switch (this) {
    met => c.iconSuccess,
    short => c.iconWarning,
    over => c.secondary,
    missed => c.iconError,
    off => c.iconSecondary,
  };
}

/// `Nexo/PlanDayStatus` da lib (`d:a6gMm`): ícone de 16 e o texto
/// (LabelSmall).
class NexoPlanDayStatus extends StatelessWidget {
  const NexoPlanDayStatus({super.key, required this.tone, this.text});

  final NexoDayTone tone;

  /// Texto no lugar do rótulo padrão (ex.: "Na meta · 1h 35min").
  final String? text;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(tone.icon, size: 16, color: tone.color(c)),
        SizedBox(width: context.spacing.xs),
        Flexible(
          child: Text(
            text ?? tone.label,
            style: Theme.of(context).textTheme.labelSmall!
                .copyWith(color: c.onSurface),
          ),
        ),
      ],
    );
  }
}
