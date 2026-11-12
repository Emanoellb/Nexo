import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firestore_access.dart';
import '../../../core/domain/local_date.dart';
import '../domain/goal.dart';
import 'goals_repository.dart';

/// `users/{uid}/goals` no Firestore: `{name, description, deadline}`. As
/// gravações não esperam o servidor ([FirestoreAccess.send]).
class FirestoreGoalsRepository implements GoalsRepository {
  FirestoreGoalsRepository(this._access, {required String? uid})
    : _user = UserDocs(uid);

  final FirestoreAccess _access;
  final UserDocs _user;

  CollectionReference<Map<String, dynamic>> _goals(FirebaseFirestore db) =>
      _user.collection(db, 'goals');

  @override
  Stream<List<Goal>> watchGoals() {
    if (!_user.signedIn) return Stream.value(const []);
    return _access
        .watchDocs(_goals)
        .map(
          (docs) =>
              [for (final doc in docs) ?goalFromFirestore(doc.id, doc.data())]
                ..sort((a, b) => a.name.compareTo(b.name)),
        );
  }

  @override
  Future<Goal> createGoal({
    required String name,
    String? description,
    LocalDate? deadline,
  }) async {
    late Goal goal;
    await _access.send((db) {
      final ref = _goals(db).doc();
      goal = Goal(
        id: ref.id,
        name: name,
        description: description,
        deadline: deadline,
      );
      return ref.set({...goal.toMap(), ...createdStamps()});
    });
    return goal;
  }

  @override
  Future<void> updateGoal(Goal goal) => _access.send(
    (db) =>
        _goals(db).doc(goal.id).update({...goal.toMap(), ...updatedStamp()}),
  );

  @override
  Future<void> deleteGoal(String goalId) =>
      _access.send((db) => _goals(db).doc(goalId).delete());
}

/// `goals/{id}` → [Goal]; `null` se não passa nas regras do app.
Goal? goalFromFirestore(String id, Map<String, dynamic>? data) {
  if (data == null) return null;
  try {
    return Goal(
      id: id,
      name: data['name'] as String,
      description: data['description'] as String?,
      deadline: localDateField(data['deadline']),
    );
  } on Object {
    return null;
  }
}
