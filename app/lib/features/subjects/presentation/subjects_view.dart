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
                  _AddSubjectRow(onTap: add),
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
    final c = context.nexoColors;
    final spacing = context.spacing;
    final next = progress.next;
    final nextText = next == null
        ? null
        : nextDeliveryText(next.title, next.dueAt!, now);
    final count =
        '${progress.done} de ${progress.total} '
        '${progress.total == 1 ? 'entrega' : 'entregas'}';
    void open() => context.push(AppRoutes.subjectDetailOf(subject.id));

    return Semantics(
      button: true,
      label: [subject.name, count, ?nextText].join(', '),
      onTap: open,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: open,
        borderRadius: BorderRadius.zero,
        child: Padding(
          // Design: LG em volta, MD até o chevron.
          padding: EdgeInsets.all(spacing.lg),
          child: Row(
            children: [
              Expanded(
                child: NexoAcademicProgress(
                  title: subject.name,
                  done: progress.done,
                  total: progress.total,
                  nextDelivery: nextText,
                  nextOverdue: progress.nextOverdue,
                ),
              ),
              SizedBox(width: spacing.md),
              Icon(LucideIcons.chevronRight, size: 20, color: c.iconSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Última linha do cartão: "+ Adicionar disciplina" em Primary 600, 56 de
/// altura.
class _AddSubjectRow extends StatelessWidget {
  const _AddSubjectRow({required this.onTap});

  static const double height = 56;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    return Semantics(
      button: true,
      label: 'Adicionar disciplina',
      onTap: onTap,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: height),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.lg),
            child: Row(
              children: [
                // Design: ícone e rótulo em Primary, MD entre eles.
                Icon(LucideIcons.plus, size: 20, color: c.primary),
                SizedBox(width: spacing.md),
                Flexible(
                  child: Text(
                    'Adicionar disciplina',
                    style: context
                        .textStyle(NexoTextStyles.labelMediumEmphasis)
                        .copyWith(color: c.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
