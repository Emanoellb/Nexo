import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../tasks/application/screen_now.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/domain/task_groups.dart';
import '../../tasks/presentation/task_text.dart';
import '../domain/subject.dart';
import 'subject_form.dart';

/// "Disciplinas" no segmentado da aba Tarefas (design de 04/11/2026): um
/// cartão com uma linha por disciplina, em ordem alfabética (progresso em
/// entregas + chevron), e "Adicionar disciplina" no fim.
class SubjectsView extends ConsumerWidget {
  const SubjectsView({super.key, required this.subjects, required this.tasks});

  /// Já sem as de exclusão pendente, em ordem alfabética.
  final List<Subject> subjects;
  final List<NexoTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final now = ref.watch(screenNowProvider);
    void add() => showSubjectForm(context);

    // Design (Tarefas 11 e 12): MD acima da lista; XL acima do vazio.
    return ListView(
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        subjects.isEmpty ? spacing.xl : spacing.md,
        spacing.lg,
        MediaQuery.paddingOf(context).bottom + spacing.xl,
      ),
      children: [
        NexoCardList(
          children: subjects.isEmpty
              ? [
                  NexoEmptyState(
                    icon: LucideIcons.bookOpen,
                    title: 'Adicione suas disciplinas',
                    message:
                        'Organize tarefas, provas e trabalhos pelas '
                        'disciplinas que você está cursando.',
                    actionLabel: 'Adicionar disciplina',
                    actionIcon: LucideIcons.plus,
                    onAction: add,
                  ),
                ]
              : [
                  for (final subject in subjects)
                    _SubjectRow(
                      key: ValueKey(subject.id),
                      subject: subject,
                      progress: subjectProgressOf(subject.id, tasks, now),
                      now: now,
                    ),
                  NexoAddRow(label: 'Adicionar disciplina', onTap: add),
                ],
        ),
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    super.key,
    required this.subject,
    required this.progress,
    required this.now,
  });

  final Subject subject;
  final SubjectProgress progress;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final next = progress.next;
    final total = progress.total;
    final count =
        '${progress.done} de $total ${total == 1 ? 'entrega' : 'entregas'}';
    return NexoProgressRow(
      title: subject.name,
      value: count,
      progress: total == 0 ? 0 : progress.done / total,
      progressSemantics: count,
      line: next == null
          ? null
          : nextDeliveryText(next.title, next.dueAt!, now),
      lineIsError: progress.nextOverdue,
      onTap: () => context.push(AppRoutes.subjectDetailOf(subject.id)),
    );
  }
}
