import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firestore_access.dart';
import '../domain/subject.dart';
import 'subjects_repository.dart';

/// `users/{uid}/subjects` no Firestore: `{name, icon}` (sem cor, regras
/// v0.9). As gravações não esperam o servidor ([FirestoreAccess.send]).
class FirestoreSubjectsRepository implements SubjectsRepository {
  FirestoreSubjectsRepository(this._access, {required String? uid})
    : _user = UserDocs(uid);

  final FirestoreAccess _access;
  final UserDocs _user;

  CollectionReference<Map<String, dynamic>> _subjects(FirebaseFirestore db) =>
      _user.collection(db, 'subjects');

  @override
  Stream<List<Subject>> watchSubjects() {
    if (!_user.signedIn) return Stream.value(const []);
    return _access
        .watchDocs(_subjects)
        .map(
          (docs) =>
              [
                for (final doc in docs)
                  ?subjectFromFirestore(doc.id, doc.data()),
              ]..sort(
                (a, b) =>
                    subjectNameKey(a.name).compareTo(subjectNameKey(b.name)),
              ),
        );
  }

  @override
  Future<Subject> createSubject({
    required String name,
    required String icon,
  }) async {
    late Subject subject;
    await _access.send((db) {
      final ref = _subjects(db).doc();
      subject = Subject(id: ref.id, name: name.trim(), icon: icon);
      return ref.set({...subject.toMap(), ...createdStamps()});
    });
    return subject;
  }

  @override
  Future<void> updateSubject(Subject subject) => _access.send(
    (db) =>
        _subjects(db)
            .doc(subject.id)
            .update({...subject.toMap(), ...updatedStamp()}),
  );

  @override
  Future<void> deleteSubject(String subjectId) =>
      _access.send((db) => _subjects(db).doc(subjectId).delete());
}

/// `subjects/{id}` → [Subject]; `null` se não passa nas regras do app.
Subject? subjectFromFirestore(String id, Map<String, dynamic>? data) {
  if (data == null) return null;
  try {
    return Subject(
      id: id,
      name: data['name'] as String,
      icon: data['icon'] as String,
    );
  } on Object {
    return null;
  }
}
