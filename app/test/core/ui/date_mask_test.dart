import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/ui/ui.dart';

/// Formata [text] como se o cursor estivesse em [cursor] logo depois da
/// edição.
TextEditingValue _format(String text, int cursor) =>
    DateMaskFormatter().formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: cursor),
      ),
    );

void main() {
  test('digitando no fim: barras entram e o cursor fica no fim', () {
    expect(_format('2', 1).text, '2');
    final third = _format('210', 3);
    expect(third.text, '21/0');
    expect(third.selection.baseOffset, 4);
    final full = _format('21032004', 8);
    expect(full.text, '21/03/2004');
    expect(full.selection.baseOffset, 10);
  });

  test('corrigir o mês no meio não leva o cursor ao fim', () {
    // "21/03/2004": apaga o "3" (cursor depois dele, posição 5).
    final deleted = _format('21/0/2004', 4);
    expect(deleted.text, '21/02/004');
    expect(deleted.selection.baseOffset, 4);

    // Digita "5" no lugar: cursor logo depois do "5".
    final typed = _format('21/05/2004', 5);
    expect(typed.text, '21/05/2004');
    expect(typed.selection.baseOffset, 5);
  });

  test('apagar a barra recoloca a barra e põe o cursor antes dela', () {
    // "21/03": backspace logo depois da barra.
    final value = _format('2103', 2);
    expect(value.text, '21/03');
    expect(value.selection.baseOffset, 2);
  });

  test('no máximo 8 dígitos; só dígitos; cursor no início fica no início', () {
    expect(_format('2103200499', 10).text, '21/03/2004');
    expect(_format('21a03', 5).text, '21/03');
    expect(_format('2103', 0).selection.baseOffset, 0);
  });
}
