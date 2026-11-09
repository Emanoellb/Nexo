import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/ui/ui.dart';
import '../../../core/domain/local_date.dart';
import '../../progress/application/progress_actions.dart';
import '../../tasks/application/screen_now.dart';
import '../domain/plan.dart';

/// Menu do plano (Planos 03, toque longo na lista; ⋯ no detalhe):
/// Editar · Definir como principal · Pausar · Encerrar antes · Arquivar ·
/// Excluir, conforme a situação do plano. No objetivo, também "Tirar deste
/// objetivo".
///
/// - Pausar e Arquivar: Snackbar com "Desfazer".
/// - Encerrar antes: confirma ("Encerrar o plano hoje?"); sem volta.
/// - Excluir: confirma; sem Desfazer (`deleting`). [onDeleted] roda antes
///   de apagar (ex.: o detalhe sai da tela).
Future<void> showPlanMenu(
  BuildContext context,
  WidgetRef ref, {
  required Plan plan,
  required Rect anchor,
  required bool isPrimary,
  bool includeEdit = false,
  bool includeUnlink = false,
  VoidCallback? onDeleted,
}) async {
  final progress = ref.read(progressActionsProvider);
  // Regra única de encerrado (Plan.isFinished): igual à lista e ao detalhe.
  final ended = plan.isFinished(
    LocalDate.fromDateTime(ref.read(screenNowProvider)),
  );
  final archived = plan.status == PlanStatus.archived;
  final open = !ended && !archived;

  void snack(String message, {String? action, VoidCallback? onAction}) {
    if (!context.mounted) return;
    showNexoSnackbar(
      context,
      message: message,
      actionLabel: action,
      onAction: onAction,
    );
  }

  final options = <(NexoMenuItem, Future<void> Function())>[
    if (includeEdit && open)
      (
        const NexoMenuItem(label: 'Editar plano', icon: LucideIcons.pencil),
        () async => context.push(AppRoutes.editPlanOf(plan.id)),
      ),
    if (open && !isPrimary)
      (
        const NexoMenuItem(
          label: 'Definir como principal',
          icon: LucideIcons.pin,
        ),
        () async {
          await progress.setPrimaryPlan(plan.id);
          snack('Plano principal definido.');
        },
      ),
    if (plan.status == PlanStatus.active)
      (
        const NexoMenuItem(label: 'Pausar plano', icon: LucideIcons.pause),
        () async {
          await progress.pausePlan(plan.id);
          snack(
            'Plano pausado.',
            action: 'Desfazer',
            onAction: () => progress.undoPausePlan(plan.id),
          );
        },
      ),
    if (plan.status == PlanStatus.paused)
      (
        const NexoMenuItem(label: 'Retomar plano', icon: LucideIcons.play),
        () async {
          await progress.resumePlan(plan.id);
          snack('Plano retomado.');
        },
      ),
    if (open)
      (
        const NexoMenuItem(label: 'Encerrar antes', icon: LucideIcons.flag),
        () async {
          final confirmed = await showNexoDialog(
            context,
            icon: LucideIcons.flag,
            title: 'Encerrar o plano hoje?',
            message:
                '“${plan.name}” termina hoje e o relatório final fica '
                'pronto. Depois não dá para retomar.',
            confirmLabel: 'Encerrar plano',
          );
          if (!confirmed) return;
          await progress.endPlanEarly(plan.id);
          snack('Plano encerrado.');
        },
      ),
    if (!archived)
      (
        const NexoMenuItem(label: 'Arquivar', icon: LucideIcons.archive),
        () async {
          final previous = plan.status;
          await progress.archivePlan(plan.id);
          snack(
            'Plano arquivado.',
            action: 'Desfazer',
            onAction: () => progress.unarchivePlan(plan.id, previous),
          );
        },
      ),
    if (includeUnlink && plan.goalId != null)
      (
        const NexoMenuItem(
          label: 'Tirar deste objetivo',
          icon: LucideIcons.unlink,
        ),
        () async {
          final goalId = plan.goalId;
          await progress.setPlanGoal(plan.id, null);
          snack(
            'Plano tirado do objetivo.',
            action: 'Desfazer',
            onAction: () => progress.setPlanGoal(plan.id, goalId),
          );
        },
      ),
    (
      const NexoMenuItem(
        label: 'Excluir plano',
        icon: LucideIcons.trash2,
        destructive: true,
      ),
      () async {
        final confirmed = await showNexoDialog(
          context,
          title: 'Excluir plano?',
          message:
              '“${plan.name}” e todas as sessões, dias e tópicos dele serão '
              'apagados. Essa ação não pode ser desfeita.',
          confirmLabel: 'Excluir plano',
          icon: LucideIcons.trash2,
          destructive: true,
        );
        if (!confirmed) return;
        // A Snackbar é do app: aparece antes de a tela do plano sair.
        snack('Plano excluído.');
        onDeleted?.call();
        await progress.deletePlan(plan.id);
      },
    ),
  ];

  final chosen = await showNexoMenu(
    context,
    anchor: anchor,
    // Toque longo: âncora no ponto tocado, e o menu cresce dali.
    growFrom: anchor.size == Size.zero ? anchor.topLeft : null,
    label: 'Ações do plano',
    items: [for (final (item, _) in options) item],
  );
  if (chosen != null && context.mounted) await options[chosen].$2();
}
