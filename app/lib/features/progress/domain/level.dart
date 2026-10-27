/// Nível a partir dos pontos (decisão de 25/10/2026): a cada 20 pontos, sobe
/// um nível. Nível = pontos ÷ 20 (parte inteira) + 1.
abstract final class NexoLevel {
  static const int pointsPerLevel = 20;

  static int levelFor(int points) => _nonNegative(points) ~/ pointsPerLevel + 1;

  /// Pontos já feitos dentro do nível atual (0–19): a barra do
  /// Nexo/LevelProgress mostra "pontos atuais / 20".
  static int pointsIntoLevel(int points) =>
      _nonNegative(points) % pointsPerLevel;

  /// Pontos que faltam para o próximo nível (1–20).
  static int pointsToNextLevel(int points) =>
      pointsPerLevel - pointsIntoLevel(points);

  static int _nonNegative(int points) => points < 0 ? 0 : points;
}
