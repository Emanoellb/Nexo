import '../domain/subject.dart';

/// `users/{uid}/subjects` (Firestore: `FirestoreSubjectsRepository`).
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
