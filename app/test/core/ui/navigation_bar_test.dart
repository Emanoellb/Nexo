import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/ui.dart';

import '../../helpers/nexo_test_app.dart';

const _destinations = [
  NexoNavigationDestination(icon: LucideIcons.house, label: 'Início'),
  NexoNavigationDestination(icon: LucideIcons.listTodo, label: 'Tarefas'),
  NexoNavigationDestination(icon: LucideIcons.target, label: 'Planos'),
  NexoNavigationDestination(
    icon: LucideIcons.calendarDays,
    label: 'Calendário',
  ),
  NexoNavigationDestination(icon: LucideIcons.user, label: 'Perfil'),
];

Widget _bar({
  int selected = 0,
  bool solid = false,
  ValueChanged<int>? onSelected,
}) {
  return nexoTestApp(
    NexoNavigationBar(
      destinations: _destinations,
      selectedIndex: selected,
      solid: solid,
      onSelected: onSelected ?? (_) {},
    ),
  );
}

void main() {
  testWidgets('nome visível só no destino selecionado', (tester) async {
    await tester.pumpWidget(_bar(selected: 2));
    expect(find.text('Planos'), findsOneWidget);
    for (final other in ['Início', 'Tarefas', 'Calendário', 'Perfil']) {
      expect(find.text(other), findsNothing, reason: other);
    }
  });

  testWidgets('todos os destinos têm nome acessível e só um está selecionado', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_bar(selected: 0));
    for (var i = 0; i < _destinations.length; i++) {
      final label = '${_destinations[i].label}, aba ${i + 1} de 5';
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(isButton: true, isSelected: i == 0, hasTapAction: true),
        reason: label,
      );
    }
    handle.dispose();
  });

  testWidgets('tocar num destino avisa o índice', (tester) async {
    int? tapped;
    await tester.pumpWidget(_bar(onSelected: (i) => tapped = i));
    await tester.tap(find.byIcon(LucideIcons.calendarDays));
    expect(tapped, 3);
  });

  testWidgets('sem botão central elevado: todos os alvos têm a mesma altura', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(selected: 0));
    final heights = tester
        .widgetList<NexoTappable>(find.byType(NexoTappable))
        .map((t) => tester.getSize(find.byWidget(t)).height)
        .toSet();
    expect(heights, {48});
  });

  testWidgets('vidro usa desfoque; versão sólida não', (tester) async {
    await tester.pumpWidget(_bar());
    expect(find.byType(BackdropFilter), findsOneWidget);

    await tester.pumpWidget(_bar(solid: true));
    expect(find.byType(BackdropFilter), findsNothing);
    final box = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.color != null);
    expect(box.color, NexoColors.light.glassFallback);
  });

  testWidgets('alvos de toque e rótulos passam nas diretrizes', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_bar(selected: 1, solid: true));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
