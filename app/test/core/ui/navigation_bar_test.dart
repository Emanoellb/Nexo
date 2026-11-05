import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/ui.dart';

import '../../helpers/nexo_test_app.dart';

/// Barra aprovada no Pen.dev em 04/11/2026 (Navigation/BottomBar).
const _destinations = [
  NexoNavigationDestination(icon: LucideIcons.house, label: 'Início'),
  NexoNavigationDestination(icon: LucideIcons.listTodo, label: 'Tarefas'),
  NexoNavigationDestination(icon: LucideIcons.target, label: 'Planos'),
  NexoNavigationDestination(icon: LucideIcons.calendarDays, label: 'Agenda'),
];

Widget _bar({
  int selected = 0,
  bool solid = false,
  ValueChanged<int>? onSelected,
  VoidCallback? onCreate,
}) {
  return nexoTestApp(
    NexoBottomBar(
      destinations: _destinations,
      selectedIndex: selected,
      solid: solid,
      onSelected: onSelected ?? (_) {},
      onCreate: onCreate ?? () {},
    ),
  );
}

/// Os alvos dos 4 destinos, na ordem.
Finder get _items => find.descendant(
  of: find.byType(NexoNavigationBar),
  matching: find.byType(NexoTappable),
);

BoxDecoration? _pill(WidgetTester tester, String label) {
  final container = tester.widget<AnimatedContainer>(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return container.decoration as BoxDecoration?;
}

Text _label(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label));

void main() {
  testWidgets('os 4 nomes ficam sempre visíveis, embaixo do ícone', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(selected: 2));
    for (final d in _destinations) {
      expect(find.text(d.label), findsOneWidget, reason: d.label);
      expect(
        tester.getCenter(find.byIcon(d.icon)).dy,
        lessThan(tester.getCenter(find.text(d.label)).dy),
        reason: '${d.label}: ícone em cima',
      );
    }
    // Perfil e Calendário saíram da barra.
    expect(find.text('Perfil'), findsNothing);
    expect(find.text('Calendário'), findsNothing);
  });

  testWidgets('nomes acessíveis "{nome}, aba n de 4" e só um selecionado', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_bar(selected: 0));
    for (var i = 0; i < _destinations.length; i++) {
      final label = '${_destinations[i].label}, aba ${i + 1} de 4';
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

  testWidgets('os 4 itens têm a mesma largura e alvo de 56 de altura', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(selected: 1));
    final sizes = [
      for (final e in _items.evaluate())
        tester.getSize(find.byWidget(e.widget)),
    ];
    expect(sizes, hasLength(4));
    expect(sizes.map((s) => s.width).toSet(), hasLength(1));
    for (final s in sizes) {
      expect(s.height, greaterThanOrEqualTo(56));
    }
  });

  testWidgets('selecionado: pílula atrás do item e nome em peso 600', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(selected: 1));
    final c = NexoColors.light;

    expect(_pill(tester, 'Tarefas')?.color, c.glassIndicator);
    expect(_pill(tester, 'Início')?.color, isNull);

    final selected = _label(tester, 'Tarefas').style!;
    expect(selected.color, c.glassContentSelected);
    expect(selected.fontVariations, [const FontVariation.weight(600)]);
    final other = _label(tester, 'Início').style!;
    expect(other.color, c.glassContent);
    expect(other.fontVariations, [const FontVariation.weight(500)]);
  });

  testWidgets('vidro usa desfoque; versão sólida troca as cores', (
    tester,
  ) async {
    final c = NexoColors.light;
    await tester.pumpWidget(_bar(selected: 0));
    expect(find.byType(BackdropFilter), findsOneWidget);

    await tester.pumpWidget(_bar(selected: 0, solid: true));
    expect(find.byType(BackdropFilter), findsNothing);
    final surface = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(NexoNavigationBar),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.color != null);
    expect(surface.color, c.glassFallback);
    expect(_pill(tester, 'Início')?.color, c.selected);
    expect(_label(tester, 'Planos').style!.color, c.onSurfaceVariant);
    expect(
      tester.widget<Icon>(find.byIcon(LucideIcons.target)).color,
      c.iconSecondary,
    );
  });

  testWidgets('"+" de 64 px em Primary, à direita, com nome "Criar"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var created = 0;
    await tester.pumpWidget(_bar(onCreate: () => created++));

    final fab = find.byType(NexoFab);
    expect(tester.getSize(fab), const Size.square(NexoFab.size));
    expect(
      tester.getCenter(fab).dx,
      greaterThan(tester.getRect(find.byType(NexoNavigationBar)).right),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Criar')),
      isSemantics(isButton: true, hasTapAction: true, isEnabled: true),
    );

    await tester.tap(fab);
    expect(created, 1);
    handle.dispose();
  });

  for (final solid in [false, true]) {
    testWidgets(
      'alvos, rótulos e contraste nas diretrizes (${solid ? 'sólida' : 'vidro'})',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_bar(selected: 1, solid: solid));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );
  }

  testWidgets('fonte ampliada (1,3) não estoura em 360 dp', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: NexoTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 360,
              child: NexoBottomBar(
                destinations: _destinations,
                selectedIndex: 3,
                onSelected: (_) {},
                onCreate: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
