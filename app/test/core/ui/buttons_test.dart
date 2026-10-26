import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/ui.dart';

import '../../helpers/nexo_test_app.dart';

void main() {
  group('NexoButton', () {
    testWidgets('chama onPressed ao tocar', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        nexoTestApp(
          NexoButton.primary(label: 'Salvar', onPressed: () => taps++),
        ),
      );
      await tester.tap(find.text('Salvar'));
      expect(taps, 1);
    });

    testWidgets('desabilitado não responde e usa as cores Disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        nexoTestApp(const NexoButton.primary(label: 'Salvar', onPressed: null)),
      );
      await tester.tap(find.text('Salvar'), warnIfMissed: false);
      final text = tester.widget<Text>(find.text('Salvar'));
      expect(text.style!.color, NexoColors.light.disabledContent);
      expect(
        tester.getSemantics(find.byType(NexoButtonShell)),
        isSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          label: 'Salvar',
        ),
      );
    });

    testWidgets('carregando: não responde, mostra spinner e anuncia', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        nexoTestApp(
          NexoButton.primary(
            label: 'Entrar',
            onPressed: () => taps++,
            loading: true,
          ),
        ),
      );
      await tester.tap(find.byType(NexoButtonShell), warnIfMissed: false);
      expect(taps, 0);
      expect(find.byType(NexoSpinner), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(NexoButtonShell)),
        isSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          label: 'Entrar, carregando',
        ),
      );
    });

    testWidgets('altura mínima de 48 px e ícones de 20 px', (tester) async {
      await tester.pumpWidget(
        nexoTestApp(
          NexoButton.secondary(
            label: 'Criar tarefa',
            leadingIcon: LucideIcons.plus,
            onPressed: () {},
          ),
        ),
      );
      expect(tester.getSize(find.byType(NexoButtonShell)).height, 48);
      expect(tester.getSize(find.byIcon(LucideIcons.plus)), const Size(20, 20));
    });

    testWidgets('expand ocupa a largura toda', (tester) async {
      await tester.pumpWidget(
        nexoTestApp(
          NexoButton.primary(label: 'Entrar', onPressed: () {}, expand: true),
        ),
      );
      // 390 de largura menos 16 de padding de cada lado.
      expect(tester.getSize(find.byType(NexoButtonShell)).width, 358);
    });

    testWidgets('tertiary aceita a cor do conteúdo (ação de Alert)', (
      tester,
    ) async {
      await tester.pumpWidget(
        nexoTestApp(
          NexoButton.tertiary(
            label: 'Ver atrasadas',
            onPressed: () {},
            contentColor: NexoColors.light.onWarningContainer,
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('Ver atrasadas'));
      expect(text.style!.color, NexoColors.light.onWarningContainer);
    });
  });

  group('NexoGoogleButton', () {
    testWidgets('texto padrão e toque', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        nexoTestApp(NexoGoogleButton(onPressed: () => taps++)),
      );
      await tester.tap(find.text('Continuar com o Google'));
      expect(taps, 1);
    });
  });

  group('NexoIconButton', () {
    testWidgets('alvo de 48 × 48 com nome acessível', (tester) async {
      await tester.pumpWidget(
        nexoTestApp(
          Center(
            child: NexoIconButton(
              icon: LucideIcons.x,
              tooltip: 'Fechar',
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(NexoTappable)), const Size(48, 48));
      expect(find.bySemanticsLabel('Fechar'), findsOneWidget);
    });
  });

  testWidgets('botões passam nas diretrizes de alvo e rótulo', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      nexoTestApp(
        Column(
          children: [
            NexoButton.primary(label: 'Salvar', onPressed: () {}),
            NexoButton.secondary(label: 'Cancelar', onPressed: () {}),
            NexoButton.tertiary(label: 'Ver todas', onPressed: () {}),
            NexoGoogleButton(onPressed: () {}),
            NexoIconButton(
              icon: LucideIcons.x,
              tooltip: 'Fechar',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
