import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/firebase_ready.dart';

void main() {
  test('fuso: IANA passa; formatos que as regras recusam viram o padrão', () {
    expect(normalizeTimeZone('America/Sao_Paulo'), 'America/Sao_Paulo');
    expect(
      normalizeTimeZone('America/Argentina/Buenos_Aires'),
      'America/Argentina/Buenos_Aires',
    );
    expect(normalizeTimeZone('Etc/GMT+3'), 'Etc/GMT+3');
    expect(normalizeTimeZone('UTC'), 'UTC');
    // Recusados pelas regras (users.timeZone): viram o padrão do Brasil.
    expect(normalizeTimeZone('GMT+03:00'), 'America/Sao_Paulo');
    expect(normalizeTimeZone(''), 'America/Sao_Paulo');
    expect(normalizeTimeZone(null), 'America/Sao_Paulo');
  });
}
