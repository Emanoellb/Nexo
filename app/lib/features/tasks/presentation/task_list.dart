import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../progress/application/progress_actions.dart';
import '../application/screen_now.dart';
import '../application/task_actions.dart';
import '../domain/task.dart';
import '../domain/task_groups.dart';
import 'task_text.dart';

/// Cabeçalho recolhível de uma seção (ListHeader com o chevron no lugar da
/// ação; design de Tarefas, 04/11/2026): o cabeçalho inteiro é o alvo;
/// chevron para cima aberto, para baixo recolhido.
class TaskSectionHeader extends StatelessWidget {
  const TaskSectionHeader({
    super.key,
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      header: true,
      expanded: expanded,
      label: '$title, $count',
      onTap: onToggle,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(context.shape.md),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: context.sizes.target),
          child: Padding(
            // Como o ListHeader: LG no começo; o chevron encosta no fim
            // (alinhado à borda do cartão, design de Tarefas 03).
            padding: EdgeInsetsDirectional.only(start: spacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: spacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium!.copyWith(
                          color: c.onSurface,
                        ),
                      ),
                      Text(
                        '$count',
                        style: textTheme.labelSmall!.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 20,
                  color: c.iconSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Exclusão com "Desfazer" (sem confirmação; design de 04/11/2026): o item
/// some na hora e só é apagado quando a Snackbar some sem o toque em
/// "Desfazer". Presa à conta (ver [DeferredDeletion]).
void deleteWithUndo(
  BuildContext context,
  DeferredDeletion deletion,
  String id, {
  required String message,
}) {
  final receipt = deletion.begin(id);
  showNexoSnackbar(
    context,
    message: message,
    actionLabel: 'Desfazer',
    onAction: () => deletion.undo(receipt),
  ).closed.then((reason) {
    if (reason != SnackBarClosedReason.action) deletion.finish(receipt);
  });
}

/// Ações de uma lista de tarefas (aba Tarefas e detalhe da disciplina):
/// concluir, adiar e excluir, sempre com Snackbar e "Desfazer" (4 s; com
/// leitor de tela, fica até a pessoa agir). Excluir não pede confirmação:
/// a tarefa some na hora e só é apagada quando a Snackbar some.
mixin TaskListActions<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Future<void> setTaskCompleted(NexoTask task, bool completed) async {
    // Lidos antes do await: depois dele a tela pode ter saído.
    final progress = ref.read(progressActionsProvider);
    await progress.setTaskCompleted(task.id, completed);
    if (!completed || !mounted) return;
    showNexoSnackbar(
      context,
      message: 'Tarefa concluída. +1 ponto',
      actionLabel: 'Desfazer',
      onAction: () => progress.setTaskCompleted(task.id, false),
    );
  }

  /// Concluir pelo deslizar ou pelo menu (o Checkbox já vibra sozinho).
  Future<void> completeTask(NexoTask task) {
    HapticFeedback.lightImpact();
    return setTaskCompleted(task, true);
  }

  Future<void> postponeTask(NexoTask task) async {
    final actions = ref.read(taskActionsProvider);
    final original = await actions.postpone(task);
    if (original == null || !mounted) return;
    showNexoSnackbar(
      context,
      message: 'Tarefa adiada para amanhã.',
      actionLabel: 'Desfazer',
      onAction: () => actions.restoreDue(original),
    );
  }

  void deleteTask(NexoTask task) => deleteWithUndo(
    context,
    ref.read(taskDeletionProvider),
    task.id,
    message: 'Tarefa excluída.',
  );

  /// Detalhe da tarefa (já editável).
  void openTask(NexoTask task) => context.push(AppRoutes.taskDetailOf(task.id));

  /// As ações do deslizar, para o toque longo.
  Future<void> showTaskMenu(NexoTask task, Rect anchor) async {
    final now = ref.read(screenNowProvider);
    final options = <(NexoMenuItem, VoidCallback)>[
      if (!task.completed)
        (
          const NexoMenuItem(label: 'Concluir', icon: LucideIcons.check),
          () => completeTask(task),
        ),
      if (task.canPostpone(now: now))
        (
          const NexoMenuItem(
            label: 'Adiar para amanhã',
            icon: LucideIcons.calendarClock,
          ),
          () => postponeTask(task),
        ),
      (
        const NexoMenuItem(
          label: 'Excluir',
          icon: LucideIcons.trash2,
          destructive: true,
        ),
        () => deleteTask(task),
      ),
    ];
    final chosen = await showNexoMenu(
      context,
      anchor: anchor,
      label: 'Ações da tarefa',
      items: [for (final (item, _) in options) item],
    );
    if (chosen != null && mounted) options[chosen].$2();
  }

  /// Uma linha de tarefa com deslizar (direita conclui; esquerda revela
  /// Adiar e Excluir), toque (detalhe) e toque longo (menu).
  Widget taskRow(
    NexoTask task, {
    required String? subject,
    required DateTime now,
    bool completedSection = false,
  }) {
    final c = context.nexoColors;
    return Builder(
      key: ValueKey(task.id),
      builder: (rowContext) {
        Rect anchor() {
          final box = rowContext.findRenderObject()! as RenderBox;
          return box.localToGlobal(Offset.zero) & box.size;
        }

        return NexoSwipeActions(
          startAction: task.completed
              ? null
              : NexoSwipeAction(
                  icon: LucideIcons.check,
                  label: 'Concluir',
                  background: c.success,
                  foreground: c.onSuccess,
                  onTrigger: () => completeTask(task),
                ),
          endActions: [
            if (task.canPostpone(now: now))
              NexoSwipeAction(
                icon: LucideIcons.calendarClock,
                label: 'Adiar',
                background: c.primaryContainer,
                foreground: c.onPrimaryContainer,
                onTrigger: () => postponeTask(task),
              ),
            NexoSwipeAction(
              icon: LucideIcons.trash2,
              label: 'Excluir',
              background: c.error,
              foreground: c.onError,
              onTrigger: () => deleteTask(task),
            ),
          ],
          child: NexoTaskItem(
            title: task.title,
            completed: task.completed,
            onCompletedChanged: (value) => setTaskCompleted(task, value),
            subject: subject,
            deadline: completedSection && task.completed
                ? completedFor(task.completedAt ?? now, now)
                : task.dueAt == null
                ? null
                : deadlineFor(
                    task.dueAt!,
                    now,
                    completed: task.completed,
                    markToday: true,
                  ),
            onTap: () => openTask(task),
            onLongPress: () => showTaskMenu(task, anchor()),
          ),
        );
      },
    );
  }

  /// Seções por prazo, cada uma num cartão com divisores, recolhíveis.
  List<Widget> taskSections(
    List<TaskGroup> groups, {
    required Set<TaskSection> collapsed,
    required ValueChanged<TaskSection> onToggle,
    required String? Function(NexoTask) subjectOf,
    required DateTime now,
  }) {
    return [
      for (final group in groups)
        Column(
          key: ValueKey(group.section),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TaskSectionHeader(
              title: group.section.label,
              count: group.tasks.length,
              expanded: !collapsed.contains(group.section),
              onToggle: () => onToggle(group.section),
            ),
            if (!collapsed.contains(group.section))
              NexoCardList(
                children: [
                  for (final task in group.tasks)
                    taskRow(
                      task,
                      subject: subjectOf(task),
                      now: now,
                      completedSection: group.section == TaskSection.completed,
                    ),
                ],
              ),
          ],
        ),
    ];
  }
}
