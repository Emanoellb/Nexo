import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import 'plan_list_item.dart';

/// Uma linha de plano (Planos 02 e detalhe do objetivo) sobre a
/// [NexoProgressRow]: toque abre o detalhe; toque longo, o menu do plano.
class PlanRow extends StatelessWidget {
  const PlanRow({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
  });

  final PlanListItem item;
  final VoidCallback onTap;
  final ValueChanged<Rect>? onLongPress;

  @override
  Widget build(BuildContext context) => NexoProgressRow(
    title: item.plan.name,
    value: item.value,
    line: item.line,
    progress: item.progress,
    progressSemantics: item.progressSemantics,
    onTap: onTap,
    onLongPress: onLongPress,
    longPressHint: 'Ações do plano',
  );
}
