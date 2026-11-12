import 'package:nexo/features/progress/data/achievements_repository.dart';

import 'in_memory_store.dart';

/// Em memória (prototipação); no bloco de integração, o Firestore.
class FakeAchievementsRepository implements AchievementsRepository {
  FakeAchievementsRepository({required this.clock});

  final DateTime Function() clock;
  final _store = InMemoryStore<EarnedAchievement>(const [], (a) => a.id);

  @override
  Stream<List<EarnedAchievement>> watchEarned() => _store.watch();

  @override
  Future<void> award(String id) async {
    if (_store.get(id) != null) return;
    _store.put(EarnedAchievement(id: id, earnedAt: clock()));
  }

  void dispose() => _store.dispose();
}
