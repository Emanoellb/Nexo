import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/core/ui/ui.dart';

import '../../helpers/nexo_test_app.dart';

void main() {
  group('NexoCheckbox', () {
    testWidgets('tocar na caixa ou no rótulo alterna', (tester) async {
      var value = false;
      await tester.pumpWidget(
        nexoTestApp(
          StatefulBuilder(
            builder: (context, setState) => NexoCheckbox(
              value: value,
              labelText: 'Lembretes',
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(NexoTappable));
      await tester.pump();
      expect(value, isTrue);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);

      await tester.tap(find.text('Lembretes'));
      await tester.pump();
      expect(value, isFalse);
      expect(find.byIcon(LucideIcons.check), findsNothing);
    });

    testWidgets('desabilitado não alterna', (tester) async {
      await tester.pumpWidget(
        nexoTestApp(
          const NexoCheckbox(
            value: false,
            labelText: 'Lembretes',
            onChanged: null,
          ),
        ),
      );
      await tester.tap(find.text('Lembretes'));
      await tester.pump();
      expect(find.byIcon(LucideIcons.check), findsNothing);
    });

    testWidgets('indeterminado mostra o traço', (tester) async {
      await tester.pumpWidget(
        nexoTestApp(NexoCheckbox(value: null, onChanged: (_) {})),
      );
      expect(find.byIcon(LucideIcons.minus), findsOneWidget);
    });

    testWidgets('semântica de checkbox marcado', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        nexoTestApp(
          NexoCheckbox(value: true, labelText: 'Lembretes', onChanged: (_) {}),
        ),
      );
      expect(
        tester.getSemantics(find.byType(NexoCheckbox)),
        isSemantics(
          label: 'Lembretes',
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('alvo de toque de 48 px', (tester) async {
      await tester.pumpWidget(
        nexoTestApp(NexoCheckbox(value: false, onChanged: (_) {})),
      );
      expect(tester.getSize(find.byType(NexoTappable)), const Size(48, 48));
    });
  });

  group('NexoTopAppBar', () {
    testWidgets('voltar chama onBack e tem nome acessível', (tester) async {
      var backs = 0;
      await tester.pumpWidget(
        nexoTestApp(
          SizedBox(
            height: 56,
            child: NexoTopAppBar(title: 'Cadastro', onBack: () => backs++),
          ),
        ),
      );
      expect(find.text('Cadastro'), findsOneWidget);
      await tester.tap(find.byTooltip('Voltar'));
      expect(backs, 1);
    });

    testWidgets('sem onBack não mostra o voltar', (tester) async {
      await tester.pumpWidget(
        nexoTestApp(
          const SizedBox(height: 56, child: NexoTopAppBar(title: 'Entrar')),
        ),
      );
      expect(find.byTooltip('Voltar'), findsNothing);
    });
  });

  group('NexoPageControl', () {
    testWidgets('lê "Passo X de N" e destaca o passo atual', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        nexoTestApp(const NexoPageControl(count: 5, index: 1)),
      );
      expect(find.bySemanticsLabel('Passo 2 de 5'), findsOneWidget);
      final dots = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((d) => d.constraints!.maxWidth)
          .toList();
      expect(dots, [8, 20, 8, 8, 8]);
      handle.dispose();
    });

    test('aceita só de 3 a 5 passos', () {
      expect(() => NexoPageControl(count: 2, index: 0), throwsAssertionError);
      expect(() => NexoPageControl(count: 6, index: 0), throwsAssertionError);
    });
  });

  group('Feedback', () {
    testWidgets('showNexoSnackbar mostra a mensagem e a ação fecha', (
      tester,
    ) async {
      var undone = 0;
      await tester.pumpWidget(
        nexoTestApp(
          Builder(
            builder: (context) => NexoButton.primary(
              label: 'Mostrar',
              onPressed: () => showNexoSnackbar(
                context,
                message: 'Tarefa concluída',
                tone: NexoSnackbarTone.success,
                actionLabel: 'Desfazer',
                onAction: () => undone++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mostrar'));
      await tester.pumpAndSettle();
      expect(find.text('Tarefa concluída'), findsOneWidget);
      expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);

      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.text('Tarefa concluída'), findsNothing);
    });

    testWidgets('Alert de erro é região viva e tem ícone além da cor', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        nexoTestApp(
          const NexoAlert(
            tone: NexoAlertTone.error,
            title: 'Não foi possível entrar',
            message: 'Confira sua conexão e tente de novo.',
          ),
        ),
      );
      expect(find.byIcon(LucideIcons.circleX), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(NexoAlert)),
        isSemantics(isLiveRegion: true),
      );
      handle.dispose();
    });
  });
}
