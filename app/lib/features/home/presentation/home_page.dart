import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/data/connectivity.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../plans/presentation/choose_primary_plan.dart';
import '../../plans/presentation/plan_today_card.dart';
import '../../tasks/application/screen_now.dart';
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

  /// Sessão simulada pelo Focar e pelo Focar mais.
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
        ScreenNowRefresh<HomePage>,
        PlanDayActions<HomePage> {
  // ---------- Ações ----------

  /// Nova tarefa em tela cheia (design da Tarefa, 07/11/2026). A tela
  /// confirma com "Tarefa criada."; se ela concluir os primeiros passos,
  /// o aviso do estado 05 toma o lugar.
  void _createTask() => context.push(AppRoutes.newTask);

  /// Criar plano em 3 passos (design de Planos 2b, 07/11/2026). O
  /// primeiro plano vira o principal sozinho.
  void _createPlan() => context.push(AppRoutes.newPlan);

  /// Na Home, a sessão que conclui os primeiros passos não ganha a
  /// Snackbar dela: quem avisa é "Primeiros passos concluídos." (estado 05).
  @override
  bool announceFocus(String planId) {
    final view = ref.read(homeViewProvider);
    final steps = view?.firstSteps;
    final completesFirstSteps =
        view != null &&
        view.showFirstSteps &&
        steps!.task &&
        steps.plan &&
        !steps.session;
    return !completesFirstSteps;
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
      if (plan != null)
        planTodayCard(
          plan,
          onChoosePrimary: () => showChoosePrimaryPlan(context, ref),
          onCreatePlan: () => context.push(AppRoutes.newPlanPrimary),
        ),
      if (plan != null && view.showFirstSteps)
        FirstStepsLine(
          steps: steps,
          onDismiss: () => ref.read(firstStepsDoneProvider.notifier).markDone(),
        ),
      _tasksBlock(view, todayBlock: true),
      if (!view.upcoming.isEmpty) _tasksBlock(view, todayBlock: false),
    ];
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
