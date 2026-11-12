import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/goals/data/goals_repository.dart';
import 'package:nexo/features/goals/domain/goal.dart';

import 'in_memory_store.dart';

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
