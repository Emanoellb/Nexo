import 'package:nexo/features/subjects/data/subjects_repository.dart';
import 'package:nexo/features/subjects/domain/subject.dart';

import 'in_memory_store.dart';

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
