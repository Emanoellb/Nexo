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
