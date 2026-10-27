import '../../../core/data/in_memory_store.dart';
import '../../../core/domain/local_date.dart';
import '../domain/goal.dart';

/// `users/{uid}/goals`. A versão Firestore entra no bloco de integração.
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

class FakeGoalsRepository implements GoalsRepository {
  final _ids = FakeIds('objetivo');
  final _goals = InMemoryStore<Goal>(const [], (g) => g.id);

  @override
  Stream<List<Goal>> watchGoals() =>
      _goals.watch(sort: (a, b) => a.name.compareTo(b.name));

  @override
  Future<Goal> createGoal({
    required String name,
    String? description,
    LocalDate? deadline,
  }) async {
    final goal = Goal(
      id: _ids.next(),
      name: name,
      description: description,
      deadline: deadline,
    );
    _goals.put(goal);
    return goal;
  }

  @override
  Future<void> updateGoal(Goal goal) async => _goals.put(goal);

  @override
  Future<void> deleteGoal(String goalId) async => _goals.remove(goalId);

  void dispose() => _goals.dispose();
}
