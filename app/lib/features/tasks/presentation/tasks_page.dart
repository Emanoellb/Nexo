import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../subjects/application/subject_actions.dart';
import '../../subjects/domain/subject.dart';
import '../../subjects/presentation/subjects_view.dart';
import '../application/screen_now.dart';
import '../application/task_actions.dart';
import '../application/task_view.dart';
import '../domain/task.dart';
import '../domain/task_groups.dart';
import 'task_list.dart';

/// O que o segmentado do topo mostra.
enum TasksSegment { tasks, subjects }

/// Tarefas (aba 2), aprovada no Pen.dev em 04/11/2026 (nexo.app.pen, Seção /
/// Tarefas). Segmentado "Tarefas | Disciplinas"; em Tarefas, chips de
/// disciplina (escolha única, "Todas" por padrão) e o botão
/// "Visualização": "Por prazo" (padrão, seções recolhíveis) ou "Hoje,
/// Próximas e Concluídas" (abas com contagem). A escolha fica no aparelho.
///
/// Estados: carregando (skeleton depois de ~300 ms) · vazio (sem chips,
/// sem o botão "Visualização") · filtro sem resultado ("Mostrar todas").
class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage>
    with
        NexoDelayedSkeleton<TasksPage>,
        TaskListActions<TasksPage>,
        ScreenNowRefresh<TasksPage> {
  final _viewButtonKey = GlobalKey();

  TasksSegment _segment = TasksSegment.tasks;

  /// Disciplina dos chips; `null` = "Todas".
  String? _subjectFilter;
  TaskTab _tab = TaskTab.today;

  /// Concluídas começa recolhida.
  final _collapsed = <TaskSection>{TaskSection.completed};

  void _toggle(TaskSection section) => setState(() {
    if (!_collapsed.remove(section)) _collapsed.add(section);
  });

  Future<void> _chooseView(TaskView current) async {
    final box = _viewButtonKey.currentContext!.findRenderObject()! as RenderBox;
    final chosen = await showNexoMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      label: 'Visualização',
      items: [
        for (final view in TaskView.values)
          NexoMenuItem(label: view.label, selected: view == current),
      ],
    );
    if (chosen == null || !mounted) return;
    await ref.read(taskViewProvider.notifier).set(TaskView.values[chosen]);
  }

  void _createTask() => context.push(AppRoutes.newTask);

  @override
  Widget build(BuildContext context) {
    // Sem as de exclusão pendente (somem na hora).
    final tasks = ref.watch(visibleTasksProvider);
    final subjects = ref.watch(visibleSubjectsProvider);
    if (!tasks.hasValue || !subjects.hasValue) {
      return whileLoading(const TasksSkeleton());
    }
    loaded();
    final subjectList = subjects.value!;
    final taskList = tasks.value!;
    scheduleNowRefresh(taskList);
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // Design (nexo.app.pen, Tarefas 03): Controles com padding
          // XS/LG/SM/LG e SM entre o segmentado e os filtros.
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.xs,
            spacing.lg,
            spacing.sm,
          ),
          child: NexoSegmented<TasksSegment>(
            segments: const [
              (value: TasksSegment.tasks, label: 'Tarefas'),
              (value: TasksSegment.subjects, label: 'Disciplinas'),
            ],
            selected: _segment,
            onChanged: (value) => setState(() => _segment = value),
          ),
        ),
        Expanded(
          child: switch (_segment) {
            TasksSegment.tasks => _tasksBody(subjectList, taskList),
            TasksSegment.subjects => SubjectsView(
              subjects: subjectList,
              tasks: taskList,
            ),
          },
        ),
      ],
    );
  }

  Widget _tasksBody(List<Subject> subjects, List<NexoTask> allTasks) {
    final spacing = context.spacing;
    final view = ref.watch(taskViewProvider);
    final now = ref.watch(screenNowProvider);
    final names = {for (final s in subjects) s.id: s.name};
    // Disciplina excluída: o filtro volta para "Todas".
    final filter = names.containsKey(_subjectFilter) ? _subjectFilter : null;

    final visible = [
      for (final t in allTasks)
        if (taskSectionOf(t, now) != null) t,
    ];
    final empty = visible.isEmpty;
    final filtered = filter == null
        ? visible
        : [
            for (final t in visible)
              if (t.subjectId == filter) t,
          ];

    final toolbar = Padding(
      // Chips e "Visualização" com XS entre eles; LG nas pontas; SM embaixo.
      padding: EdgeInsetsDirectional.only(end: spacing.lg, bottom: spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsetsDirectional.only(start: spacing.lg),
              child: Row(
                children: [
                  for (final (id, label) in [
                    (null, 'Todas'),
                    for (final s in subjects) (s.id, s.name),
                  ]) ...[
                    NexoFilterChip(
                      label: label,
                      selected: filter == id,
                      onSelected: () => setState(() => _subjectFilter = id),
                    ),
                    SizedBox(width: spacing.sm),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: spacing.xs),
          _ViewButton(
            key: _viewButtonKey,
            changed: view != TaskView.byDue,
            onPressed: () => _chooseView(view),
          ),
        ],
      ),
    );

    // Topo da lista (design): por prazo 0; abas e filtro sem resultado MD;
    // vazio XL. Entre grupos, LG.
    final bottom = MediaQuery.paddingOf(context).bottom;
    EdgeInsets listPadding(double top) =>
        EdgeInsets.fromLTRB(spacing.lg, top, spacing.lg, bottom + spacing.xl);

    if (empty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sem tarefas, sem chips nem "Visualização" (pedido do usuário,
          // 06/11/2026): o botão volta com a primeira tarefa.
          Expanded(
            child: ListView(
              padding: listPadding(spacing.xl),
              children: [
                NexoCardList(
                  children: [
                    NexoEmptyState(
                      icon: LucideIcons.listTodo,
                      title: 'Suas tarefas aparecem aqui',
                      message:
                          'Crie tarefas com prazo, prioridade e disciplina. '
                          'Elas também aparecem no Início e na Agenda.',
                      actionLabel: 'Criar uma tarefa',
                      actionIcon: LucideIcons.plus,
                      onAction: _createTask,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    String? subjectOf(NexoTask t) => names[t.subjectId];
    // Filtro sem resultado (design 06): sem cartão, ação Tertiary.
    Widget noResults(({String title, String message}) copy) => NexoEmptyState(
      icon: LucideIcons.searchX,
      title: copy.title,
      message: copy.message,
      actionLabel: 'Mostrar todas',
      tertiaryAction: true,
      onAction: () => setState(() => _subjectFilter = null),
    );

    final List<Widget> children;
    Widget? tabs;
    switch (view) {
      case TaskView.byDue:
        final groups = groupTasksByDue(filtered, now);
        children = groups.isEmpty
            ? [noResults(_filteredEmpty(names[filter]!, null))]
            : taskSections(
                groups,
                collapsed: _collapsed,
                onToggle: _toggle,
                subjectOf: subjectOf,
                now: now,
              );
      case TaskView.tabs:
        final byTab = tasksByTab(filtered, now);
        tabs = NexoTabs(
          tabs: [
            for (final tab in TaskTab.values)
              (label: tab.label, count: byTab[tab]!.length),
          ],
          selected: _tab.index,
          onSelected: (i) => setState(() => _tab = TaskTab.values[i]),
        );
        final list = byTab[_tab]!;
        children = [
          if (list.isEmpty)
            filter != null
                ? noResults(_filteredEmpty(names[filter]!, _tab))
                : NexoCardList(children: [_tabEmpty()])
          else
            NexoCardList(
              children: [
                for (final task in list)
                  taskRow(
                    task,
                    subject: subjectOf(task),
                    now: now,
                    completedSection: _tab == TaskTab.completed,
                  ),
              ],
            ),
        ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toolbar,
        ?tabs,
        Expanded(
          child: ListView.separated(
            padding: listPadding(tabs == null ? 0 : spacing.md),
            itemCount: children.length,
            separatorBuilder: (_, _) => SizedBox(height: spacing.lg),
            itemBuilder: (_, i) => children[i],
          ),
        ),
      ],
    );
  }

  /// Filtro sem resultado. A aba Hoje segue o design (Tarefas 06); as
  /// outras e a visão por prazo seguem o mesmo molde.
  ({String title, String message}) _filteredEmpty(
    String subject,
    TaskTab? tab,
  ) => switch (tab) {
    TaskTab.today => (
      title: 'Nada de $subject para hoje',
      message: 'As tarefas de $subject com prazo para hoje aparecem aqui.',
    ),
    TaskTab.upcoming => (
      title: 'Nada de $subject nas próximas',
      message: 'As tarefas de $subject de amanhã em diante aparecem aqui.',
    ),
    TaskTab.completed => (
      title: 'Nada de $subject concluído',
      message:
          'As tarefas de $subject concluídas nos últimos 7 dias aparecem '
          'aqui.',
    ),
    null => (
      title: 'Nada de $subject por aqui',
      message: 'As tarefas de $subject aparecem aqui.',
    ),
  };

  Widget _tabEmpty() => switch (_tab) {
    TaskTab.today => const NexoEmptyState(
      icon: LucideIcons.circleCheck,
      title: 'Nada para hoje',
      message: 'Tarefas com prazo para hoje e atrasadas aparecem aqui.',
    ),
    TaskTab.upcoming => const NexoEmptyState(
      icon: LucideIcons.calendarDays,
      title: 'Nada nas próximas',
      message: 'Tarefas de amanhã em diante e sem prazo aparecem aqui.',
    ),
    TaskTab.completed => const NexoEmptyState(
      icon: LucideIcons.listChecks,
      title: 'Nenhuma concluída',
      message: 'Tarefas concluídas nos últimos 7 dias aparecem aqui.',
    ),
  };
}

/// Botão "Visualização" (só ícone, 48): com uma visualização diferente da
/// padrão, ganha um ponto de 8 em Primary.
class _ViewButton extends StatelessWidget {
  const _ViewButton({
    super.key,
    required this.changed,
    required this.onPressed,
  });

  static const double dot = 8;

  final bool changed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NexoIconButton(
          icon: LucideIcons.listFilter,
          tooltip: 'Visualização',
          onPressed: onPressed,
        ),
        if (changed)
          PositionedDirectional(
            top: context.spacing.md,
            end: context.spacing.md,
            child: IgnorePointer(
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: context.nexoColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Carregando: skeleton dos chips e de dois grupos. Anuncia "Carregando as
/// tarefas"; estático com "reduzir movimento".
class TasksSkeleton extends StatelessWidget {
  const TasksSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final chip = NexoFilterChip.visualHeight;

    return NexoSkeletonScope(
      label: 'Carregando as tarefas',
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          spacing.lg,
          spacing.sm,
          spacing.lg,
          MediaQuery.paddingOf(context).bottom + spacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NexoSkeleton(
              height: context.sizes.target,
              radius: context.shape.md,
            ),
            SizedBox(height: spacing.lg),
            Row(
              children: [
                for (final w in [64.0, 88.0, 112.0]) ...[
                  NexoSkeleton(
                    width: w,
                    height: chip,
                    radius: context.shape.sm,
                  ),
                  SizedBox(width: spacing.sm),
                ],
              ],
            ),
            SizedBox(height: spacing.xl),
            const NexoSkeletonList(titleWidth: 90, rows: 2),
            SizedBox(height: spacing.xl),
            const NexoSkeletonList(titleWidth: 120),
          ],
        ),
      ),
    );
  }
}
