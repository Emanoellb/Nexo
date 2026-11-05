import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/ui.dart';

/// Acessibilidade de sistema (auditoria de 05/11/2026): Snackbar com ação e
/// leitor de tela (A1), negrito do sistema (A2), fonte em 200% (A3) e a
/// vibração ao concluir tarefa.
void main() {
  group('Snackbar', () {
    Future<void> show(
      WidgetTester tester, {
      required bool accessible,
      bool withAction = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NexoTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(accessibleNavigation: accessible),
            child: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: NexoButton.primary(
                    label: 'Mostrar',
                    onPressed: () => showNexoSnackbar(
                      context,
                      message: 'Tarefa concluída.',
                      actionLabel: withAction ? 'Desfazer' : null,
                      onAction: withAction ? () {} : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mostrar'));
      await tester.pumpAndSettle();
    }

    testWidgets('sem leitor de tela, some em 4 s', (tester) async {
      await show(tester, accessible: false);
      expect(find.text('Tarefa concluída.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Tarefa concluída.'), findsNothing);
    });

    testWidgets('com leitor de tela e "Desfazer", fica e ganha Fechar', (
      tester,
    ) async {
      await show(tester, accessible: true);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('Tarefa concluída.'), findsOneWidget);
      expect(find.byTooltip('Fechar'), findsOneWidget);
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();
      expect(find.text('Tarefa concluída.'), findsNothing);
    });

    testWidgets('sem ação, some mesmo com leitor de tela', (tester) async {
      await show(tester, accessible: true, withAction: false);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Tarefa concluída.'), findsNothing);
    });

    testWidgets('na fila, não apaga a atual', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NexoTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: NexoButton.primary(
                  label: 'Mostrar',
                  onPressed: () {
                    showNexoSnackbar(
                      context,
                      message: 'Primeiros passos concluídos.',
                    );
                    showNexoSnackbar(
                      context,
                      message: '"Tarefa 1" criada para hoje.',
                      queue: true,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mostrar'));
      await tester.pumpAndSettle();
      expect(find.text('Primeiros passos concluídos.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('"Tarefa 1" criada para hoje.'), findsOneWidget);
    });
  });

  group('negrito do sistema', () {
    test('+200 no peso e no eixo wght, até 800', () {
      final regular = withBoldText(NexoTextStyles.bodyMedium);
      expect(regular.fontWeight, FontWeight.w600);
      expect(regular.fontVariations, [const FontVariation.weight(600)]);
      final heading = withBoldText(NexoTextStyles.headingLarge);
      expect(heading.fontVariations, [const FontVariation.weight(800)]);
    });

    testWidgets('tema e estilos fixos seguem MediaQuery.boldText', (
      tester,
    ) async {
      late TextStyle themed;
      late TextStyle fixed;
      await tester.pumpWidget(
        MaterialApp(
          theme: NexoTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(boldText: true),
            child: Builder(
              builder: (context) => Theme(
                data: NexoTheme.withSystemText(context, Theme.of(context)),
                child: Builder(
                  builder: (context) {
                    themed = Theme.of(context).textTheme.bodyMedium!;
                    fixed = context.textStyle(NexoTextStyles.labelSmall);
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(themed.fontVariations, [const FontVariation.weight(600)]);
      expect(fixed.fontVariations, [const FontVariation.weight(700)]);
    });
  });

  testWidgets('concluir tarefa vibra de leve; reabrir não', (tester) async {
    final calls = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String?);
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
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: NexoTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => NexoTaskItem(
              title: 'Revisar UML',
              completed: completed,
              onCompletedChanged: (v) => setState(() => completed = v),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(NexoCheckbox));
    await tester.pump();
    expect(calls, ['HapticFeedbackType.lightImpact']);
    await tester.tap(find.byType(NexoCheckbox));
    await tester.pump();
    expect(calls, hasLength(1));
  });

  group('fonte em 200% (A3)', () {
    setUp(() {});

    Future<void> pumpAt2x(WidgetTester tester, Widget child) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: NexoTheme.light(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                child: Padding(padding: const EdgeInsets.all(16), child: child),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('barra de abas em 360 dp não estoura', (tester) async {
      await pumpAt2x(
        tester,
        NexoBottomBar(
          destinations: const [
            NexoNavigationDestination(icon: LucideIcons.house, label: 'Início'),
            NexoNavigationDestination(
              icon: LucideIcons.listTodo,
              label: 'Tarefas',
            ),
            NexoNavigationDestination(
              icon: LucideIcons.target,
              label: 'Planos',
            ),
            NexoNavigationDestination(
              icon: LucideIcons.calendarDays,
              label: 'Agenda',
            ),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
          onCreate: () {},
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('cartão do plano em 360 dp: ações empilham, alvo ≥ 48', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpAt2x(
        tester,
        NexoPlanCard(
          dayLabel: 'Dia 23 de 300',
          title: 'Concurso Banco Horizonte',
          progressLabel: 'Hoje · 1h 10min de 1h 30min',
          progressDetail: 'Faltam 20 min',
          progress: 0.7,
          streakLabel: '12 dias seguidos',
          primaryAction: NexoButton.primary(
            label: 'Focar',
            leadingIcon: LucideIcons.play,
            expand: true,
            onPressed: () {},
          ),
          tertiaryLabel: 'Finalizar o dia',
          onTertiary: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      // Em 200%, o "Finalizar o dia" vai para baixo do Focar.
      expect(
        tester.getTopLeft(find.text('Finalizar o dia')).dy,
        greaterThan(tester.getBottomLeft(find.text('Focar')).dy),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
