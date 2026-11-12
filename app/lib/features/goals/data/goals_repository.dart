import '../../../core/domain/local_date.dart';
import '../domain/goal.dart';

/// `users/{uid}/goals` (Firestore: `FirestoreGoalsRepository`).
abstract interface class GoalsRepository {
  Stream<List<Goal>> watchGoals();

  Future<Goal> createGoal({
    required String name,
    String? description,
    LocalDate? deadline,
  });

  Future<void> updateGoal(Goal goal);
  Future<void> deleteGoal(String goalId);
}
