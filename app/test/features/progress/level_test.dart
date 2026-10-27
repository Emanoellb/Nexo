import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/features/progress/domain/level.dart';

void main() {
  test('nível = pontos ÷ 20 (parte inteira) + 1', () {
    expect(NexoLevel.levelFor(0), 1);
    expect(NexoLevel.levelFor(19), 1);
    expect(NexoLevel.levelFor(20), 2);
    expect(NexoLevel.levelFor(38), 2);
    expect(NexoLevel.levelFor(40), 3);
  });

  test('barra do nível: pontos atuais / 20 e quanto falta', () {
    expect(NexoLevel.pointsIntoLevel(37), 17);
    expect(NexoLevel.pointsToNextLevel(37), 3);
    expect(NexoLevel.pointsIntoLevel(40), 0);
    expect(NexoLevel.pointsToNextLevel(40), 20);
  });

  test('pontos negativos contam como zero', () {
    expect(NexoLevel.levelFor(-5), 1);
    expect(NexoLevel.pointsIntoLevel(-5), 0);
  });
}
