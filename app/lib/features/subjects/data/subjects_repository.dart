import '../../../core/data/in_memory_store.dart';
import '../domain/subject.dart';

/// `users/{uid}/subjects`. A versão Firestore entra no bloco de integração.
abstract interface class SubjectsRepository {
  /// Em ordem alfabética (sem diferença de acento e maiúsculas).
  Stream<List<Subject>> watchSubjects();

  Future<Subject> createSubject({required String name, required String icon});

  Future<void> updateSubject(Subject subject);

  /// Apaga a disciplina. As tarefas dela continuam, sem disciplina: quem
  /// chama limpa o `subjectId` delas no mesmo lote (no Firestore, um
  /// `WriteBatch`; ver `SubjectActions`).
  Future<void> deleteSubject(String subjectId);
}

class FakeSubjectsRepository implements SubjectsRepository {
  final _ids = FakeIds('disciplina');
  final _subjects = InMemoryStore<Subject>(const [], (s) => s.id);

  @override
  Stream<List<Subject>> watchSubjects() => _subjects.watch(
    sort: (a, b) => subjectNameKey(a.name).compareTo(subjectNameKey(b.name)),
  );

  @override
  Future<Subject> createSubject({
    required String name,
    required String icon,
  }) async {
    final subject = Subject(id: _ids.next(), name: name.trim(), icon: icon);
    _subjects.put(subject);
    return subject;
  }

  @override
  Future<void> updateSubject(Subject subject) async => _subjects.put(subject);

  @override
  Future<void> deleteSubject(String subjectId) async =>
      _subjects.remove(subjectId);

  void dispose() => _subjects.dispose();
}
