import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/local_date.dart';
import '../buttons/nexo_icon_button.dart';
import 'nexo_text_field.dart';

/// `Input/Date` da lib (`d:ds8UE`): o [NexoTextField] com a máscara
/// DD/MM/AAAA e o calendário no fim do campo.
///
/// A tela mostra sempre DD/MM/AAAA; quem grava converte para `AAAA-MM-DD`
/// ([LocalDate.toIso]).
class NexoDateField extends StatelessWidget {
  const NexoDateField({
    super.key,
    required this.label,
    required this.controller,
    required this.firstDate,
    required this.lastDate,
    this.initialPickerDate,
    this.focusNode,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.textInputAction,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;

  /// Limites do calendário.
  final DateTime firstDate;
  final DateTime lastDate;

  /// Mês que o calendário abre quando o campo está vazio.
  final DateTime? initialPickerDate;
  final FocusNode? focusNode;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final TextInputAction? textInputAction;

  /// Chamado ao digitar e ao escolher no calendário.
  final ValueChanged<String>? onChanged;

  DateTime _initialDate() {
    DateTime? typed;
    try {
      typed = LocalDate.parseDisplay(controller.text).startOfDay;
    } on FormatException {
      typed = null;
    }
    final initial = typed ?? initialPickerDate ?? lastDate;
    if (initial.isBefore(firstDate)) return firstDate;
    if (initial.isAfter(lastDate)) return lastDate;
    return initial;
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _initialDate(),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: label,
      fieldHintText: 'DD/MM/AAAA',
    );
    if (picked == null) return;
    final text = LocalDate.fromDateTime(picked).toDisplay();
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    onChanged?.call(text);
    // O campo perde o foco como se a pessoa tivesse saído dele.
    focusNode?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return NexoTextField(
      label: label,
      controller: controller,
      focusNode: focusNode,
      hintText: 'DD/MM/AAAA',
      helperText: helperText,
      errorText: errorText,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      autocorrect: false,
      inputFormatters: [DateMaskFormatter()],
      onChanged: onChanged,
      trailing: NexoIconButton(
        icon: LucideIcons.calendar,
        tooltip: 'Abrir calendário',
        iconSize: 20,
        onPressed: enabled ? () => _pick(context) : null,
      ),
    );
  }
}

/// Só dígitos, com as barras inseridas: `21032004` → `21/03/2004`.
///
/// O cursor fica depois do mesmo dígito em que estava, para editar no meio
/// (ex.: corrigir o mês) sem ele pular para o fim.
class DateMaskFormatter extends TextInputFormatter {
  static final _nonDigit = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(_nonDigit, '');
    final clipped = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(clipped[i]);
    }
    final text = buffer.toString();

    // Quantos dígitos havia antes do cursor no texto digitado.
    final cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, newValue.text.length)
        : newValue.text.length;
    final before = newValue.text
        .substring(0, cursor)
        .replaceAll(_nonDigit, '')
        .length
        .clamp(0, clipped.length);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: _offsetAfter(before, text)),
    );
  }

  /// Posição logo depois do [count]-ésimo dígito de [text].
  static int _offsetAfter(int count, String text) {
    if (count == 0) return 0;
    var seen = 0;
    for (var i = 0; i < text.length; i++) {
      if (text[i] != '/') seen++;
      if (seen == count) return i + 1;
    }
    return text.length;
  }
}
