import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/domain/local_date.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../progress/application/progress_actions.dart';
import '../../tasks/application/screen_now.dart';
import '../application/plans_providers.dart';
import '../domain/plan.dart';
import 'plan_text.dart';

/// "Escolher plano principal" (Planos 04, pelo Início 14): painel com os
/// planos ativos. Tocar num plano o define como principal e fecha.
Future<void> showChoosePrimaryPlan(BuildContext context, WidgetRef ref) async {
  final plans = (ref.read(plansProvider).value ?? const <Plan>[])
      .where((p) => p.status == PlanStatus.active)
      .toList();
  final today = LocalDate.fromDateTime(ref.read(screenNowProvider));
  final progress = ref.read(progressActionsProvider);
  final chosen = await showNexoBottomSheet<String>(
    context,
    title: 'Escolher plano principal',
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: sheetContext.spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final plan in plans)
            NexoListItem(
              key: ValueKey(plan.id),
              icon: LucideIcons.target,
              title: plan.name,
              supporting: planSummaryLine(plan, today),
              showChevron: false,
              onTap: () => Navigator.of(sheetContext).pop(plan.id),
            ),
        ],
      ),
    ),
  );
  if (chosen == null || !context.mounted) return;
  await progress.setPrimaryPlan(chosen);
  if (context.mounted) {
    showNexoSnackbar(context, message: 'Plano principal definido.');
  }
}
