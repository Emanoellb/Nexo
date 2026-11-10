import '../../../core/data/in_memory_store.dart';

/// Uma medalha ganha: `users/{uid}/achievements/{id}` com `earnedAt`
/// (carimbo do servidor; contrato §4). Não muda depois; só sai ao excluir a
/// conta.
class EarnedAchievement {
  const EarnedAchievement({required this.id, required this.earnedAt});

  final String id;
  final DateTime earnedAt;
}

/// Medalhas ganhas da conta atual.
abstract interface class AchievementsRepository {
  Stream<List<EarnedAchievement>> watchEarned();

  /// Grava a medalha [id] uma vez só (já ganha: nada muda).
  Future<void> award(String id);
}

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
