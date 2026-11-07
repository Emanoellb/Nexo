import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/ui.dart';

/// Ajustes da auditoria de design e do code review (05/11/2026): menu pelo
/// tamanho real, alça do BottomSheet, indicador das abas e deslizar em
/// idioma da direita para a esquerda.
Widget _app(Widget Function(BuildContext) builder, {TextDirection? dir}) =>
    MaterialApp(
      theme: NexoTheme.light(),
      home: Scaffold(
        body: Directionality(
          textDirection: dir ?? TextDirection.ltr,
          child: Builder(builder: builder),
        ),
      ),
    );

void main() {
  testWidgets('menu com fonte 2,0 perto da base abre acima e cabe na tela', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1500); // 360 × 500
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const anchor = Rect.fromLTWH(296, 440, 48, 48);

    await tester.pumpWidget(
      _app(
        (context) => Center(
          child: NexoButton.primary(
            label: 'Abrir',
            onPressed: () => showNexoMenu(
              context,
              anchor: anchor,
              items: const [
                NexoMenuItem(label: 'Concluir', icon: LucideIcons.check),
                NexoMenuItem(label: 'Adiar', icon: LucideIcons.calendarClock),
                NexoMenuItem(
                  label: 'Excluir',
                  icon: LucideIcons.trash2,
                  destructive: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final menu = tester.getRect(find.byType(NexoMenu));
    expect(menu.bottom, lessThanOrEqualTo(anchor.top));
    expect(menu.top, greaterThanOrEqualTo(0));
    expect(menu.right, lessThanOrEqualTo(360));
  });

  testWidgets('BottomSheet: alça de 48 "Fechar" e Elevation/3', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        (context) => Center(
          child: NexoButton.primary(
            label: 'Abrir',
            onPressed: () => showNexoBottomSheet<void>(
              context,
              title: 'Nova disciplina',
              builder: (_) => const SizedBox(height: 120),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Nova disciplina'), findsOneWidget);

    final shadow = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(NexoBottomSheet),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.boxShadow != null);
    expect(shadow.boxShadow, NexoElevation.standard.level(3));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.tap(find.bySemanticsLabel('Fechar'));
    await tester.pumpAndSettle();
    expect(find.text('Nova disciplina'), findsNothing);
    handle.dispose();
  });

  testWidgets('abas: indicador só sob o conteúdo e papel de aba', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        (_) => NexoTabs(
          tabs: const [
            (label: 'Hoje', count: 3),
            (label: 'Próximas', count: 2),
            (label: 'Concluídas', count: null),
          ],
          selected: 0,
          onSelected: (_) {},
        ),
      ),
    );
    final indicator = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).border is Border &&
          ((w.decoration! as BoxDecoration).border! as Border).bottom.color ==
              NexoColors.light.primary,
    );
    expect(indicator, findsOneWidget);
    final tabWidth = tester.getSize(find.byType(NexoTabs)).width / 3;
    expect(tester.getSize(indicator).width, lessThan(tabWidth - 16));
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Hoje, 3, aba 1 de 3'))
          .getSemanticsData()
          .role,
      SemanticsRole.tab,
    );
    handle.dispose();
  });

  for (final dir in TextDirection.values) {
    testWidgets('deslizar revela as ações do fim da linha ($dir)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var deleted = 0;
      await tester.pumpWidget(
        _app(
          (_) => NexoSwipeActions(
            endActions: [
              NexoSwipeAction(
                icon: LucideIcons.trash2,
                label: 'Excluir',
                background: NexoColors.light.error,
                foreground: NexoColors.light.onError,
                onTrigger: () => deleted++,
              ),
            ],
            child: const SizedBox(height: 64, child: Text('Tarefa')),
          ),
          dir: dir,
        ),
      );
      // Rumo ao começo da linha: à esquerda em LTR, à direita em RTL.
      final towardStart = dir == TextDirection.ltr ? -120.0 : 120.0;
      await tester.drag(find.text('Tarefa'), Offset(towardStart, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Excluir').last);
      await tester.pumpAndSettle();
      expect(deleted, 1);
      handle.dispose();
    });
  }
}
