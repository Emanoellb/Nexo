import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/ui.dart';

/// Melhorias de animação (transições §8, aprovadas em 08/11/2026).
const _motion = NexoMotion.standardMotion;

Widget _app(Widget child, {bool reduce = false}) => MaterialApp(
  theme: NexoTheme.light(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
      child: Scaffold(body: child),
    ),
  ),
);

Widget _list(List<String> items) => SingleChildScrollView(
  child: NexoCardList(
    children: [
      for (final i in items)
        SizedBox(key: ValueKey(i), height: 60, child: Text(i)),
    ],
  ),
);

double _height(WidgetTester tester, String item) => tester
    .getSize(
      find.ancestor(of: find.text(item), matching: find.byType(SizeTransition)),
    )
    .height;

void main() {
  test('curvas M3 e distâncias (§8.2 e §8.3)', () {
    expect(_motion.standard, const Cubic(0.2, 0, 0, 1));
    expect(_motion.enter, const Cubic(0.05, 0.7, 0.1, 1));
    expect(_motion.exit, const Cubic(0.3, 0, 0.8, 0.15));
    expect(_motion.emphasized, Curves.easeInOutCubicEmphasized);
    expect(_motion.distancePage, 30);
    expect(_motion.distanceLarge, 16);
    expect(_motion.scaleEnter, 0.92);
  });

  testWidgets('item sai fechando a altura (Short) e volta crescendo '
      '(Medium)', (tester) async {
    await tester.pumpWidget(_app(_list(['A', 'B', 'C'])));
    final bTop = tester.getTopLeft(find.text('C')).dy;

    // Sai o B: no meio, ainda na tela e mais baixo; os de baixo sobem.
    await tester.pumpWidget(_app(_list(['A', 'C'])));
    await tester.pump(_motion.short * 0.5);
    expect(find.text('B'), findsOneWidget);
    expect(_height(tester, 'B'), lessThan(61));
    expect(tester.getTopLeft(find.text('C')).dy, lessThan(bTop));
    await tester.pump(_motion.short);
    await tester.pumpAndSettle();
    expect(find.text('B'), findsNothing);

    // Desfazer: volta na mesma posição, crescendo.
    await tester.pumpWidget(_app(_list(['A', 'B', 'C'])));
    await tester.pump(_motion.medium * 0.3);
    expect(_height(tester, 'B'), lessThan(61));
    expect(
      tester.getTopLeft(find.text('B')).dy,
      lessThan(tester.getTopLeft(find.text('C')).dy),
    );
    await tester.pumpAndSettle();
    expect(_height(tester, 'B'), greaterThanOrEqualTo(60));
  });

  testWidgets('vários de uma vez saem juntos; reduzir movimento é na hora', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_list(['A', 'B', 'C', 'D'])));
    await tester.pumpWidget(_app(_list(['A', 'D'])));
    await tester.pump(_motion.short * 0.5);
    expect(_height(tester, 'B'), _height(tester, 'C'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_app(_list(['A', 'B']), reduce: true));
    await tester.pumpWidget(_app(_list(['A']), reduce: true));
    await tester.pump();
    expect(find.text('B'), findsNothing);
  });

  testWidgets('"Desfazer" durante a saída reaproveita o item (sem chave '
      'repetida)', (tester) async {
    await tester.pumpWidget(_app(_list(['A', 'B', 'C'])));
    await tester.pumpWidget(_app(_list(['A', 'C'])));
    await tester.pump(_motion.short * 0.5);
    await tester.pumpWidget(_app(_list(['A', 'B', 'C'])));
    await tester.pump(_motion.short * 0.5);
    expect(tester.takeException(), isNull);
    expect(find.text('B'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(_height(tester, 'B'), greaterThanOrEqualTo(60));
  });

  testWidgets('ligar "reduzir movimento" durante a entrada não quebra', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_list(['A'])));
    await tester.pumpWidget(_app(_list(['A', 'B'])));
    await tester.pump(_motion.medium * 0.3);
    await tester.pumpWidget(_app(_list(['A']), reduce: true));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('toque longo não vibra; o menu cresce do ponto tocado', (
    tester,
  ) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    Rect? anchor;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => NexoProgressRow(
            title: 'Concurso Banco Horizonte',
            value: 'Dia 23 de 300',
            line: 'Hoje · 1h 10min de 1h 30min',
            onTap: () {},
            onLongPress: (rect) {
              anchor = rect;
              showNexoMenu(
                context,
                anchor: rect,
                growFrom: rect.topLeft,
                items: const [NexoMenuItem(label: 'Pausar plano')],
              );
            },
          ),
        ),
      ),
    );
    const point = Offset(120, 40);
    await tester.longPressAt(point);
    await tester.pump();
    expect(haptics, isEmpty);
    expect(anchor!.topLeft, point);
    expect(anchor!.size, Size.zero);

    // No começo, o menu está em Scale/Enter, com a origem no ponto tocado.
    await tester.pump(const Duration(milliseconds: 1));
    final grow = tester
        .widgetList<Transform>(
          find.ancestor(
            of: find.byType(NexoMenu),
            matching: find.byType(Transform),
          ),
        )
        .firstWhere((t) => t.origin == point);
    expect(grow.transform.storage[0], closeTo(_motion.scaleEnter, 0.02));
    await tester.pumpAndSettle();
    expect(find.text('Pausar plano'), findsOneWidget);

    // Ao fechar, só esmaece (Instant · Exit): a escala fica em 1.
    await tester.tapAt(const Offset(10, 790));
    await tester.pump();
    final closing = tester
        .widgetList<Transform>(
          find.ancestor(
            of: find.byType(NexoMenu),
            matching: find.byType(Transform),
          ),
        )
        .where((t) => t.origin == point);
    for (final t in closing) {
      expect(t.transform.storage[0], 1);
    }
    await tester.pumpAndSettle();
  });
}
