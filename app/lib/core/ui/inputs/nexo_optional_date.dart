import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/local_date.dart';
import '../menu/nexo_menu.dart';

/// Resultado de [pickOptionalDate]: a data escolhida, ou `null` em
/// [date] quando a pessoa escolheu "Sem …".
typedef OptionalDatePick = ({LocalDate? date});

/// Data opcional (prazo da tarefa e do objetivo): com data, o toque abre o
/// `Menu/Select` "Escolher data" / [clearLabel] (ex.: "Sem prazo"); sem
/// data, abre direto o calendário. O calendário vai de [firstDate] a
/// [lastDate] e aceita a data atual mesmo antes de [firstDate].
///
/// Devolve `null` se a pessoa cancelou.
Future<OptionalDatePick?> pickOptionalDate(
  BuildContext context, {
  required Rect anchor,
  required String label,
  required String clearLabel,
  required LocalDate? current,
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTime fallbackInitial,
}) async {
  if (current != null) {
    final chosen = await showNexoMenu(
      context,
      anchor: anchor,
      label: label,
      alignEnd: false,
      items: [
        const NexoMenuItem(label: 'Escolher data', icon: LucideIcons.calendar),
        NexoMenuItem(label: clearLabel, icon: LucideIcons.calendarX),
      ],
    );
    if (chosen == null || !context.mounted) return null;
    if (chosen == 1) return (date: null);
  }
  final currentDay = current?.startOfDay;
  final first = currentDay != null && currentDay.isBefore(firstDate)
      ? currentDay
      : firstDate;
  var initial = currentDay ?? fallbackInitial;
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(lastDate)) initial = lastDate;
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: lastDate,
    helpText: label,
  );
  if (picked == null) return null;
  return (date: LocalDate.fromDateTime(picked));
}
