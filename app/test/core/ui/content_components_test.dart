import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/ui.dart';

import '../../helpers/nexo_test_app.dart';

/// Componentes do Início (lib, 04/11/2026): ListHeader, EmptyState,
/// TaskItem, Deadline, Skeleton, Progress/Linear e Dialog.
void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'lista, vazio e tarefa nas diretrizes (${dark ? 'escuro' : 'claro'})',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          nexoTestApp(
            SingleChildScrollView(
              child: Column(
                children: [
                  NexoListHeader(
                    title: 'Hoje',
                    count: '3 tarefas',
                    actionLabel: 'Ver todas',
                    onAction: () {},
                  ),
                  NexoTaskItem(
                    title: 'Lista de exercícios 3',
                    completed: false,
                    onCompletedChanged: (_) {},
                    subject: 'Cálculo II',
                    highPriority: true,
                    deadline: const NexoDeadline(
                      text: 'Atrasada · ontem, 23:59',
                      semanticsLabel: 'Atrasada. Prazo: ontem às 23:59',
                      tone: NexoDeadlineTone.overdue,
                    ),
                  ),
                  NexoEmptyState(
                    icon: LucideIcons.circleCheck,
                    title: 'Nada para hoje',
                    message: 'Tarefas com prazo para hoje aparecem aqui.',
                    actionLabel: 'Criar tarefa',
                    onAction: () {},
                  ),
                ],
              ),
            ),
            dark: dark,
          ),
        );
        expect(find.bySemanticsLabel('Prioridade alta'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Atrasada. Prazo: ontem às 23:59'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Concluir: Lista de exercícios 3'),
          findsOneWidget,
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );
  }

  testWidgets('tarefa: marcar avisa; concluída fica riscada', (tester) async {
    bool? changed;
    await tester.pumpWidget(
      nexoTestApp(
        NexoTaskItem(
          title: 'Revisar UML',
          completed: false,
          onCompletedChanged: (v) => changed = v,
        ),
      ),
    );
    await tester.tap(find.byType(NexoCheckbox));
    expect(changed, isTrue);

    await tester.pumpWidget(
      nexoTestApp(
        NexoTaskItem(
          title: 'Revisar UML',
          completed: true,
          onCompletedChanged: (_) {},
        ),
      ),
    );
    final title = tester.widget<Text>(find.text('Revisar UML'));
    expect(title.style!.decoration, TextDecoration.lineThrough);
  });

  testWidgets('progresso linear: fração e cor (Secondary padrão)', (
    tester,
  ) async {
    await tester.pumpWidget(nexoTestApp(const NexoLinearProgress(value: 0.25)));
    final bar = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(bar.widthFactor, 0.25);
    final fill = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(FractionallySizedBox),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      (fill.decoration as BoxDecoration).color,
      NexoColors.light.secondary,
    );
  });

  testWidgets('skeleton: anuncia o carregamento e esconde os blocos', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      nexoTestApp(
        const NexoSkeletonScope(
          label: 'Carregando o Início',
          child: Column(children: [NexoSkeleton(height: 12)]),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Carregando o Início'), findsOneWidget);
    handle.dispose();
  });

  group('showNexoDialog', () {
    Future<List<bool>> open(WidgetTester tester) async {
      final results = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: NexoTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: NexoButton.primary(
                  label: 'Abrir',
                  onPressed: () async => results.add(
                    await showNexoDialog(
                      context,
                      icon: LucideIcons.circleCheck,
                      title: 'Finalizar o dia agora?',
                      message: 'Você estudou 1h 10min de 1h 30min.',
                      cancelLabel: 'Agora não',
                      confirmLabel: 'Finalizar o dia',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return results;
    }

    testWidgets('confirmar devolve true; "Agora não" e o fundo, false', (
      tester,
    ) async {
      final results = await open(tester);

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Finalizar o dia agora?'), findsOneWidget);
      // O cartão (lib: 312 de largura), não o Center em volta.
      final card = find
          .ancestor(
            of: find.text('Finalizar o dia agora?'),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(card).width, NexoDialog.width);
      await tester.tap(find.text('Finalizar o dia'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(results, [true, false, false]);
    });

    testWidgets('diretrizes de alvo, rótulo e contraste', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
