import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/prototype/prototype_actions.dart';
import '../../../core/data/connectivity.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../plans/domain/plan.dart';
import '../../plans/domain/plan_day_result.dart';
import '../../progress/application/progress_actions.dart';
import '../../tasks/application/screen_now.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_list.dart';
import '../application/home_view.dart';
import 'home_text.dart';
import 'home_widgets.dart';

/// Início (aba 1), aprovado no Pen.dev em 04/11/2026 (nexo.app.pen, Seção /
/// Início e · Escuro). Ordem: Plano do dia → Hoje → Próximas entregas; uma
/// ação principal por estado (Hick) e até 3 itens por lista (Miller). Sem
/// nível nem pontos na tela.
///
/// Estados: 01 carregando (skeleton depois de ~300 ms) · 02–05 primeiros
/// passos · 06 uso diário · 07 finalizar abaixo da meta (diálogo) · 08/09
/// dia cumprido · 10 sem conexão (alerta no topo).
///
/// Na prototipação, as telas de criar e o cronômetro ainda não existem: os
/// botões criam exemplos e registram 25 min (decisão do usuário, 04/11).
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  /// Sessão simulada pelo Focar e pelo Estudar mais.
  static const focusMinutes = 25;

  /// Até quantos itens cada lista mostra (Miller).
  static const maxItems = 3;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with
        NexoDelayedSkeleton<HomePage>,
        TaskListActions<HomePage>,
        ScreenNowRefresh<HomePage> {
  // Lidos antes dos awaits: depois deles a tela pode já ter saído (logout,
  // troca de conta) e o `ref` não pode mais ser usado.
  ProgressActions get _progress => ref.read(progressActionsProvider);
  PrototypeActions get _prototype => ref.read(prototypeActionsProvider);

  /// O dia que o cartão mostra (o mesmo "agora" da tela).
  LocalDate get _today => LocalDate.fromDateTime(ref.read(screenNowProvider));

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

  // ---------- Ações ----------

  Future<void> _createTask() async {
    // Se esta tarefa conclui os primeiros passos, quem avisa é a Snackbar
    // "Primeiros passos concluídos." (estado 05), não esta.
    final view = ref.read(homeViewProvider);
    final steps = view?.firstSteps;
    final completesFirstSteps =
        view != null &&
        view.showFirstSteps &&
        !steps!.task &&
        steps.plan &&
        steps.session;
    final task = await _prototype.createSampleTask();
    if (!completesFirstSteps) _snack('"${task.title}" criada para hoje.');
  }

  Future<void> _createPlan({bool makePrimary = false}) async {
    final plan = await _prototype.createSamplePlan(makePrimary: makePrimary);
    _snack('"${plan.name}" criado.');
  }

  Future<void> _resume(HomePlanToday plan) async {
    await _progress.resumePlan(plan.plan.id);
    _snack('Plano retomado.');
  }

  Future<void> _focus(HomePlanToday plan) async {
    // Se esta sessão conclui os primeiros passos, quem avisa é a Snackbar
    // "Primeiros passos concluídos." (estado 05), não esta.
    final view = ref.read(homeViewProvider);
    final steps = view?.firstSteps;
    final completesFirstSteps =
        view != null &&
        view.showFirstSteps &&
        steps!.task &&
        steps.plan &&
        !steps.session;
    await _progress.addFocusMinutes(plan.plan.id, HomePage.focusMinutes);
    if (!completesFirstSteps) {
      _snack('Sessão de ${HomePage.focusMinutes} min registrada.');
    }
  }

  Future<void> _finalize(HomePlanToday plan) async {
    final result = plan.today;
    final progress = _progress;
    final day = _today;
    // RF15: só pede confirmação abaixo da meta.
    final short = formatMinutes(-result.differenceMinutes);
    final confirmed = await showNexoDialog(
      context,
      icon: LucideIcons.circleCheck,
      iconColor: context.nexoColors.iconSuccess,
      title: 'Finalizar o dia agora?',
      message:
          'Você estudou ${formatMinutes(result.doneMinutes)} de '
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

  void _goToBranch(int index) =>
      StatefulNavigationShell.of(context).goBranch(index);

  // ---------- Tela ----------

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(homeViewProvider);
    final online = ref.watch(onlineProvider).value ?? true;

    // Primeiros passos concluídos agora: some o cartão e avisa (estado 05).
    ref.listen(homeViewProvider, (previous, next) {
      if (previous == null || next == null) return;
      if (previous.showFirstSteps &&
          !previous.firstSteps.complete &&
          next.firstSteps.complete) {
        ref.read(firstStepsDoneProvider.notifier).markDone();
        // Na frente de tudo: nenhuma confirmação na fila ("criada", "criado")
        // pode passar antes nem apagar este aviso.
        if (mounted) {
          showNexoSnackbar(
            context,
            message: 'Primeiros passos concluídos.',
            tone: NexoSnackbarTone.success,
            clearQueue: true,
          );
        }
      }
    });

    if (view == null) return whileLoading(const HomeSkeleton());
    loaded();
    scheduleNowRefresh([...view.today.tasks, ...view.upcoming.tasks]);

    final spacing = context.spacing;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final sections = <Widget>[
      if (!online)
        NexoAlert(
          tone: NexoAlertTone.info,
          icon: LucideIcons.wifiOff,
          title: 'Você está sem conexão',
          message:
              'Mostrando o que está salvo no aparelho. As mudanças '
              'sincronizam quando a conexão voltar.',
          actionLabel: 'Tentar agora',
          onAction: () => ref.invalidate(onlineProvider),
        ),
      ..._content(view),
    ];

    return RefreshIndicator(
      color: context.nexoColors.primary,
      backgroundColor: context.nexoColors.surfaceContainerLowest,
      // Dados locais: puxar só confere a rede de novo.
      onRefresh: () async => ref.invalidate(onlineProvider),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          spacing.lg,
          spacing.sm,
          spacing.lg,
          bottom + spacing.xl,
        ),
        itemCount: sections.length,
        separatorBuilder: (_, _) => SizedBox(height: spacing.xl),
        itemBuilder: (_, i) => sections[i],
      ),
    );
  }

  List<Widget> _content(HomeView view) {
    final plan = view.plan;
    final steps = view.firstSteps;

    // 02/03: sem plano ainda, o cartão completo de primeiros passos.
    if (plan == null && view.showFirstSteps) {
      return [
        HomeWelcome(steps: steps),
        FirstStepsCard(
          steps: steps,
          onCreateTask: _createTask,
          onCreatePlan: _createPlan,
        ),
        if (steps.done == 0)
          const HomeTip()
        else if (!view.today.isEmpty)
          _tasksBlock(view, todayBlock: true),
      ];
    }

    return [
      if (plan != null) _planCard(plan),
      if (plan != null && view.showFirstSteps)
        FirstStepsLine(
          steps: steps,
          onDismiss: () => ref.read(firstStepsDoneProvider.notifier).markDone(),
        ),
      _tasksBlock(view, todayBlock: true),
      if (!view.upcoming.isEmpty) _tasksBlock(view, todayBlock: false),
    ];
  }

  /// `Nexo/PlanCard` nos 8 estados do pacote B (aprovado em 05/11/2026,
  /// pen.dev/notas/inicio-pacote-b-especificacao.md §2).
  Widget _planCard(HomePlanToday plan) {
    final result = plan.today;
    final done = formatMinutes(result.doneMinutes);
    final goal = formatMinutes(result.goalMinutes);
    final status = result.status;
    final streak = streakText(plan.streak);
    final focus = NexoButton.primary(
      label: 'Focar',
      leadingIcon: LucideIcons.play,
      expand: true,
      onPressed: () => _focus(plan),
    );

    // Arquivado ou encerrado: escolher outro principal ou criar um (nada é
    // promovido sozinho). O fim do período conta como encerrado.
    final ended = plan.isClosed || plan.dayNumber > plan.totalDays;
    if (ended) {
      final archived = plan.plan.status == PlanStatus.archived;
      return NexoPlanCard(
        dayLabel: archived ? 'Arquivado' : 'Encerrado',
        title: plan.plan.name,
        progressLabel: archived
            ? 'Seu plano principal foi arquivado'
            : 'Seu plano principal foi encerrado',
        progress: null,
        primaryAction: plan.otherActivePlans
            ? NexoButton.primary(
                label: 'Escolher plano principal',
                leadingIcon: LucideIcons.target,
                expand: true,
                // Lista de planos sem design: vai à aba Planos (decisão do
                // usuário, 05/11/2026).
                onPressed: () => _goToBranch(2),
              )
            : NexoButton.primary(
                label: 'Criar plano',
                leadingIcon: LucideIcons.plus,
                expand: true,
                onPressed: () => _createPlan(makePrimary: true),
              ),
      );
    }

    if (plan.isPaused) {
      final since = plan.openPause?.start;
      return NexoPlanCard(
        dayLabel: 'Pausado',
        title: plan.plan.name,
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
          onPressed: () => _resume(plan),
        ),
      );
    }

    final String dayLabel;
    if (plan.dayNumber < 1) {
      dayLabel = 'Começa em ${plan.plan.startDate.toDisplay()}';
    } else if (result.restDay) {
      dayLabel = result.doneMinutes > 0 ? 'Folga · estudo extra' : 'Folga';
    } else {
      dayLabel = 'Dia ${plan.dayNumber} de ${plan.totalDays}';
    }

    // Cumprido (meta batida, com ou sem finalizar; ou finalizado abaixo).
    if (status.isFulfilled) {
      final diff = result.differenceMinutes;
      return NexoPlanCard(
        dayLabel: dayLabel,
        title: plan.plan.name,
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
          label: 'Estudar mais',
          leadingIcon: LucideIcons.play,
          expand: true,
          onPressed: () => _focus(plan),
        ),
      );
    }

    // Folga sem estudo: "Estudar mesmo assim" (Tertiary), sem Focar como
    // ação principal. Também antes do início do plano.
    if (status == PlanDayStatus.off) {
      final next = plan.nextStudyDay;
      return NexoPlanCard(
        dayLabel: dayLabel,
        title: plan.plan.name,
        progressLabel: plan.dayNumber < 1
            ? 'O plano ainda não começou'
            : 'Hoje é folga neste plano',
        progressDetail: next == null ? null : 'Próximo: ${shortDayText(next)}',
        progress: null,
        streakLabel: streak,
        primaryAction: NexoButton.tertiary(
          label: 'Estudar mesmo assim',
          leadingIcon: LucideIcons.play,
          expand: true,
          onPressed: () => _focus(plan),
        ),
      );
    }

    // Normal (ou folga com estudo). "Finalizar o dia" só com estudo e
    // abaixo da meta: oculto com 0 min.
    final missing = (result.goalMinutes - result.doneMinutes).clamp(0, 1440);
    final canFinalize = result.doneMinutes > 0;
    return NexoPlanCard(
      dayLabel: dayLabel,
      title: plan.plan.name,
      progressLabel: 'Hoje · $done de $goal',
      progressDetail: 'Faltam ${formatMinutes(missing)}',
      progress: result.goalMinutes == 0
          ? 0
          : result.doneMinutes / result.goalMinutes,
      progressSemantics: '$done de $goal',
      streakLabel: streak,
      primaryAction: focus,
      tertiaryLabel: canFinalize ? 'Finalizar o dia' : null,
      onTertiary: canFinalize ? () => _finalize(plan) : null,
    );
  }

  Widget _tasksBlock(HomeView view, {required bool todayBlock}) {
    final group = todayBlock ? view.today : view.upcoming;
    final now = ref.read(screenNowProvider);
    final String count;
    if (!todayBlock) {
      count = '7 dias';
    } else if (group.completed > 0) {
      count = '${group.completed} de ${group.tasks.length} concluídas';
    } else {
      count = tasksCount(group.tasks.length);
    }

    final header = NexoListHeader(
      title: todayBlock ? 'Hoje' : 'Próximas entregas',
      count: group.isEmpty ? null : count,
      actionLabel: todayBlock ? 'Ver todas' : 'Ver agenda',
      onAction: () => _goToBranch(todayBlock ? 1 : 3),
    );

    final Widget body;
    if (group.isEmpty) {
      body = NexoCardList(
        children: [
          NexoEmptyState(
            icon: LucideIcons.circleCheck,
            title: 'Nada para hoje',
            message:
                'Tarefas com prazo para hoje aparecem aqui. Aproveite para '
                'adiantar a semana.',
            actionLabel: 'Criar tarefa',
            actionIcon: LucideIcons.plus,
            onAction: _createTask,
          ),
        ],
      );
    } else {
      body = NexoCardList(
        children: [
          for (final task in group.tasks.take(HomePage.maxItems))
            NexoTaskItem(
              key: ValueKey(task.id),
              title: task.title,
              completed: task.completed,
              onCompletedChanged: (value) => setTaskCompleted(task, value),
              subject: view.subjects[task.subjectId],
              highPriority: task.priority == TaskPriority.high,
              deadline: task.dueAt == null
                  ? null
                  : deadlineFor(
                      task.dueAt!,
                      now,
                      completed: task.completed,
                      markToday: todayBlock,
                    ),
              // Tocar abre o detalhe, como em Tarefas.
              onTap: () => openTask(task),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, body],
    );
  }
}
