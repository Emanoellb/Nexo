import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/domain/local_date.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../../core/format/duration_text.dart';
import '../../progress/application/progress_actions.dart';
import '../../tasks/application/screen_now.dart';
import '../application/plan_today.dart';
import '../domain/plan.dart';
import '../domain/plan_day_result.dart';
import 'plan_text.dart';

/// Minutos da sessão de exemplo do "Focar" enquanto a tela de Foco não
/// existe (só para teste; sai antes da produção, decisão do usuário de
/// 07/11/2026).
const simulatedFocusMinutes = 25;

/// O cartão "Hoje" de um plano (`Nexo/PlanCard`) e as ações dele (Focar,
/// Finalizar o dia, Retomar), no Início e na Visão geral do plano.
mixin PlanDayActions<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  void _snack(
    String message, {
    NexoSnackbarTone tone = NexoSnackbarTone.none,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!mounted) return;
    showNexoSnackbar(
      context,
      message: message,
      tone: tone,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  Future<void> resumePlan(String planId) async {
    await ref.read(progressActionsProvider).resumePlan(planId);
    _snack('Plano retomado.');
  }

  /// Se a Snackbar da sessão aparece (a Home cala quando a sessão conclui
  /// os primeiros passos).
  bool announceFocus(String planId) => true;

  /// "Focar": por enquanto registra uma sessão de exemplo (só para teste;
  /// a tela de Foco entra na branch dela e isto sai antes da produção).
  Future<void> focusPlan(String planId) async {
    final announce = announceFocus(planId);
    await ref
        .read(progressActionsProvider)
        .addFocusMinutes(planId, simulatedFocusMinutes);
    if (announce) _snack('Sessão de $simulatedFocusMinutes min registrada.');
  }

  Future<void> finalizePlanDay(PlanToday plan) async {
    final result = plan.today;
    final progress = ref.read(progressActionsProvider);
    final day = LocalDate.fromDateTime(ref.read(screenNowProvider));
    // RF15: só pede confirmação abaixo da meta.
    final short = formatMinutes(-result.differenceMinutes);
    final confirmed = await showNexoDialog(
      context,
      icon: LucideIcons.circleCheck,
      iconColor: context.nexoColors.iconSuccess,
      title: 'Finalizar o dia agora?',
      message:
          'Você fez ${formatMinutes(result.doneMinutes)} de '
          '${formatMinutes(result.goalMinutes)}. O dia conta como cumprido, '
          'com $short a menos no relatório, e a sequência continua. Ainda '
          'dá para registrar horas até 7 dias depois.',
      cancelLabel: 'Agora não',
      confirmLabel: 'Finalizar o dia',
    );
    if (!confirmed || !mounted) return;
    final planId = plan.plan.id;
    await progress.finalizeDay(planId, day);
    _snack(
      'Dia finalizado com $short a menos.',
      tone: NexoSnackbarTone.success,
      actionLabel: 'Desfazer',
      onAction: () => progress.undoFinalizeDay(planId, day),
    );
  }

  /// `Nexo/PlanCard` nos 8 estados do pacote B (aprovado em 05/11/2026,
  /// pen.dev/notas/inicio-pacote-b-especificacao.md §2).
  Widget planTodayCard(
    PlanToday plan, {
    bool showTitle = true,
    VoidCallback? onChoosePrimary,
    VoidCallback? onCreatePlan,
  }) {
    final result = plan.today;
    final done = formatMinutes(result.doneMinutes);
    final goal = formatMinutes(result.goalMinutes);
    final status = result.status;
    final streak = streakText(plan.streak);
    final focus = NexoButton.primary(
      label: 'Focar',
      leadingIcon: LucideIcons.play,
      expand: true,
      onPressed: () => focusPlan(plan.plan.id),
    );

    // Arquivado ou encerrado: escolher outro principal ou criar um (nada é
    // promovido sozinho). O fim do período conta como encerrado.
    final ended = plan.isClosed;
    if (ended) {
      final archived = plan.plan.status == PlanStatus.archived;
      return NexoPlanCard(
        dayLabel: archived ? 'Arquivado' : 'Encerrado',
        title: showTitle ? plan.plan.name : null,
        progressLabel: archived
            ? 'Seu plano principal foi arquivado'
            : 'Seu plano principal foi encerrado',
        progress: null,
        primaryAction: plan.otherActivePlans
            ? NexoButton.primary(
                label: 'Escolher plano principal',
                leadingIcon: LucideIcons.target,
                expand: true,
                onPressed: onChoosePrimary,
              )
            : NexoButton.primary(
                label: 'Criar plano',
                leadingIcon: LucideIcons.plus,
                expand: true,
                onPressed: onCreatePlan,
              ),
      );
    }

    if (plan.isPaused) {
      final since = plan.openPause?.start;
      return NexoPlanCard(
        dayLabel: 'Pausado',
        title: showTitle ? plan.plan.name : null,
        progressLabel: since == null
            ? 'Plano pausado'
            : 'Pausado desde ${since.day}/${since.month}',
        progressDetail: 'Dias pausados não contam',
        progress: null,
        streakLabel: '$streak · sequência mantida',
        primaryAction: NexoButton.secondary(
          label: 'Retomar plano',
          leadingIcon: LucideIcons.play,
          expand: true,
          onPressed: () => resumePlan(plan.plan.id),
        ),
      );
    }

    final String dayLabel;
    if (plan.dayNumber < 1) {
      dayLabel = 'Começa em ${plan.plan.startDate.toDisplay()}';
    } else if (result.restDay) {
      dayLabel = result.doneMinutes > 0 ? 'Folga · sessão extra' : 'Folga';
    } else {
      dayLabel = 'Dia ${plan.dayNumber} de ${plan.totalDays}';
    }

    // Cumprido (meta batida, com ou sem finalizar; ou finalizado abaixo).
    if (status.isFulfilled) {
      final diff = result.differenceMinutes;
      return NexoPlanCard(
        dayLabel: dayLabel,
        title: showTitle ? plan.plan.name : null,
        progressLabel: 'Dia cumprido · $done',
        progressDetail: switch (status) {
          PlanDayStatus.metOver => '+${formatMinutes(diff)} da meta',
          PlanDayStatus.metShort => '−${formatMinutes(diff)} da meta',
          _ => 'Na meta',
        },
        progress: result.goalMinutes == 0
            ? 1
            : result.doneMinutes / result.goalMinutes,
        completed: true,
        progressSemantics: '$done de $goal',
        streakLabel: streak,
        primaryAction: NexoButton.secondary(
          label: 'Focar mais',
          leadingIcon: LucideIcons.play,
          expand: true,
          onPressed: () => focusPlan(plan.plan.id),
        ),
      );
    }

    // Folga sem estudo: "Estudar mesmo assim" (Tertiary), sem Focar como
    // ação principal. Também antes do início do plano.
    if (status == PlanDayStatus.off) {
      final next = plan.nextStudyDay;
      return NexoPlanCard(
        dayLabel: dayLabel,
        title: showTitle ? plan.plan.name : null,
        progressLabel: plan.dayNumber < 1
            ? 'O plano ainda não começou'
            : 'Hoje é folga neste plano',
        progressDetail: next == null ? null : 'Próximo: ${shortDayText(next)}',
        progress: null,
        streakLabel: streak,
        primaryAction: NexoButton.tertiary(
          label: 'Focar mesmo assim',
          leadingIcon: LucideIcons.play,
          expand: true,
          onPressed: () => focusPlan(plan.plan.id),
        ),
      );
    }

    // Normal (ou folga com estudo). "Finalizar o dia" só com estudo e
    // abaixo da meta: oculto com 0 min.
    final missing = (result.goalMinutes - result.doneMinutes).clamp(0, 1440);
    final canFinalize = result.doneMinutes > 0;
    return NexoPlanCard(
      dayLabel: dayLabel,
      title: showTitle ? plan.plan.name : null,
      progressLabel: 'Hoje · $done de $goal',
      progressDetail: 'Faltam ${formatMinutes(missing)}',
      progress: result.goalMinutes == 0
          ? 0
          : result.doneMinutes / result.goalMinutes,
      progressSemantics: '$done de $goal',
      streakLabel: streak,
      primaryAction: focus,
      tertiaryLabel: canFinalize ? 'Finalizar o dia' : null,
      onTertiary: canFinalize ? () => finalizePlanDay(plan) : null,
    );
  }
}
