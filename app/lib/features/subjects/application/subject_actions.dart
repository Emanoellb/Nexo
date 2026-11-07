import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tasks/application/task_actions.dart';
import '../../tasks/application/tasks_providers.dart';
import '../domain/subject.dart';
import 'subjects_providers.dart';

/// Disciplinas com exclusão pendente (somem na hora; o definitivo só quando
/// a Snackbar com "Desfazer" some).
final pendingSubjectDeletionsProvider =
    NotifierProvider<PendingDeletions, Set<String>>(PendingDeletions.new);

/// Excluir disciplina com "Desfazer" (as tarefas dela continuam).
final subjectDeletionProvider = Provider<DeferredDeletion>(
  (ref) => DeferredDeletion(
    ref,
    pendingSubjectDeletionsProvider,
    (id) => ref.read(subjectActionsProvider).delete(id),
  ),
);

/// As disciplinas sem as de exclusão pendente, em ordem alfabética.
final visibleSubjectsProvider = Provider<AsyncValue<List<Subject>>>((ref) {
  final pending = ref.watch(pendingSubjectDeletionsProvider);
  return ref
      .watch(subjectsProvider)
      .whenData(
        (subjects) => [
          for (final s in subjects)
            if (!pending.contains(s.id)) s,
        ],
      );
});

/// Erro do campo "Nome" do cadastro de disciplina, ou `null` se válido
/// (design de 04/11/2026). Nome repetido compara sem acento e sem
/// maiúsculas; [editingId] é a própria disciplina, na edição.
String? subjectNameError(
  String name,
  Iterable<Subject> existing, {
  String? editingId,
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Informe o nome da disciplina.';
  if (trimmed.length > Subject.maxNameLength) {
    return 'Use até ${Subject.maxNameLength} caracteres.';
  }
  final key = subjectNameKey(trimmed);
  final duplicate = existing.any(
    (s) => s.id != editingId && subjectNameKey(s.name) == key,
  );
  return duplicate ? 'Você já tem uma disciplina com esse nome.' : null;
}

class SubjectActions {
  SubjectActions(this._ref);

  final Ref _ref;

  Future<Subject> create({required String name, required String icon}) => _ref
      .read(subjectsRepositoryProvider)
      .createSubject(name: name.trim(), icon: icon);

  Future<void> update(
    Subject subject, {
    required String name,
    required String icon,
  }) => _ref
      .read(subjectsRepositoryProvider)
      .updateSubject(subject.copyWith(name: name.trim(), icon: icon));

  /// Exclusão definitiva: as tarefas da disciplina CONTINUAM, sem disciplina
  /// (`subjectId` limpo). No Firestore, tudo num `WriteBatch`; no fake, em
  /// sequência.
  Future<void> delete(String subjectId) async {
    final tasks = _ref.read(tasksRepositoryProvider);
    for (final task in await tasks.watchTasks().first) {
      if (task.subjectId == subjectId) {
        await tasks.updateTask(task.copyWith(subjectId: () => null));
      }
    }
    await _ref.read(subjectsRepositoryProvider).deleteSubject(subjectId);
  }
}

final subjectActionsProvider = Provider<SubjectActions>(SubjectActions.new);
