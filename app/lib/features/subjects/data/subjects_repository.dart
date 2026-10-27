import '../../../core/data/in_memory_store.dart';
import '../domain/subject.dart';

/// `users/{uid}/subjects`. A versão Firestore entra no bloco de integração.
abstract interface class SubjectsRepository {
  /// Em ordem alfabética.
  Stream<List<Subject>> watchSubjects();

  Future<Subject> createSubject({
    required String name,
    required String icon,
    required String color,
  });

  Future<void> updateSubject(Subject subject);
  Future<void> deleteSubject(String subjectId);
}

class FakeSubjectsRepository implements SubjectsRepository {
  final _ids = FakeIds('disciplina');
  final _subjects = InMemoryStore<Subject>(const [], (s) => s.id);

  @override
  Stream<List<Subject>> watchSubjects() =>
      _subjects.watch(sort: (a, b) => a.name.compareTo(b.name));

  @override
  Future<Subject> createSubject({
    required String name,
    required String icon,
    required String color,
  }) async {
    final subject = Subject(
      id: _ids.next(),
      name: name,
      icon: icon,
      color: color,
    );
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
