import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../tasks/application/task_actions.dart';
import '../../tasks/application/screen_now.dart';
import '../../tasks/domain/task_groups.dart';
import '../../tasks/presentation/task_list.dart';
import '../../tasks/presentation/task_text.dart';
import '../application/subject_actions.dart';
import '../domain/subject.dart';
import 'subject_form.dart';

/// Detalhe da disciplina (design de 04/11/2026), dentro da aba Tarefas (a
/// barra de baixo continua): TopAppBar com voltar, o nome e "Mais opções"
/// (Editar e Excluir); cartão de progresso; só as tarefas dela, por prazo,
/// em seções recolhíveis (Concluídas recolhida).
class SubjectDetailPage extends ConsumerStatefulWidget {
  const SubjectDetailPage({super.key, required this.subjectId});

  final String subjectId;

  @override
  ConsumerState<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

class _SubjectDetailPageState extends ConsumerState<SubjectDetailPage>
    with
        TaskListActions<SubjectDetailPage>,
        ScreenNowRefresh<SubjectDetailPage> {
  final _moreKey = GlobalKey();
  final _collapsed = <TaskSection>{TaskSection.completed};
  bool _leaving = false;

  void _back() {
    if (_leaving) return;
    _leaving = true;
    context.pop();
  }

  Subject? get _subject => ref
      .read(visibleSubjectsProvider)
      .value
      ?.where((s) => s.id == widget.subjectId)
      .firstOrNull;

  Future<void> _edit() async {
    final subject = _subject;
    if (subject == null) return;
    final result = await showSubjectForm(context, editing: subject);
    if (result == SubjectFormResult.deleteRequested && mounted) {
      await _delete();
    }
  }

  /// Excluir pede confirmação (pedido do usuário, 06/11/2026) e ainda
  /// mostra "Desfazer" depois.
  Future<void> _delete() async {
    final subject = _subject;
    if (subject == null) return;
    final confirmed = await confirmDeleteSubject(context, subject);
    if (!confirmed || !mounted) return;
    // A Snackbar fica na casca: sai daqui e avisa lá.
    deleteSubjectWithUndo(context, ref, widget.subjectId);
    _back();
  }

  Future<void> _more() async {
    final box = _moreKey.currentContext!.findRenderObject()! as RenderBox;
    final chosen = await showNexoMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      label: 'Mais opções',
      items: const [
        NexoMenuItem(label: 'Editar disciplina', icon: LucideIcons.pencil),
        NexoMenuItem(
          label: 'Excluir disciplina',
          icon: LucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (!mounted) return;
    switch (chosen) {
      case 0:
        await _edit();
      case 1:
        await _delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    // Sem as de exclusão pendente (somem na hora).
    final subjects = ref.watch(visibleSubjectsProvider);
    final tasks = ref.watch(visibleTasksProvider);
    final subject = subjects.value
        ?.where((s) => s.id == widget.subjectId)
        .firstOrNull;

    // Excluída (aqui ou em outro lugar): volta para a lista.
    if (subjects.hasValue && subject == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _back();
      });
    }

    final bar = NexoTopAppBar(
      title: subject?.name ?? '',
      onBack: _back,
      actions: [
        NexoIconButton(
          key: _moreKey,
          icon: LucideIcons.ellipsis,
          tooltip: 'Mais opções',
          color: c.iconDefault,
          onPressed: subject == null ? null : _more,
        ),
      ],
    );

    if (subject == null || !tasks.hasValue) {
      return Scaffold(appBar: bar, body: const SizedBox.expand());
    }

    final now = ref.watch(screenNowProvider);
    final mine = [
      for (final t in tasks.value!)
        if (t.subjectId == subject.id) t,
    ];
    scheduleNowRefresh(mine);
    final progress = subjectProgressOf(subject.id, mine, now);
    final next = progress.next;
    final groups = groupTasksByDue(mine, now);

    final children = <Widget>[
      // Design (Tarefas 13): cartão "Resumo" em Shape/LG com "Entregas".
      NexoCard(
        radius: context.shape.lg,
        child: NexoAcademicProgress(
          title: 'Entregas',
          done: progress.done,
          total: progress.total,
          nextDelivery: next == null
              ? null
              : nextDeliveryText(next.title, next.dueAt!, now),
          nextOverdue: progress.nextOverdue,
        ),
      ),
      if (groups.isEmpty)
        const NexoCardList(
          children: [
            NexoEmptyState(
              icon: LucideIcons.listTodo,
              title: 'Nenhuma tarefa nesta disciplina',
              message:
                  'Crie uma tarefa pelo + da barra e escolha esta disciplina.',
            ),
          ],
        )
      else
        ...taskSections(
          groups,
          collapsed: _collapsed,
          onToggle: (section) => setState(() {
            if (!_collapsed.remove(section)) _collapsed.add(section);
          }),
          // Design: a linha mostra a disciplina, como na aba Tarefas.
          subjectOf: (_) => subject.name,
          now: now,
        ),
    ];

    return Scaffold(
      appBar: bar,
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          spacing.lg,
          spacing.sm,
          spacing.lg,
          MediaQuery.paddingOf(context).bottom + spacing.xl,
        ),
        itemCount: children.length,
        separatorBuilder: (_, _) => SizedBox(height: spacing.lg),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}
