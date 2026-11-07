import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/ui.dart';

import '../../helpers/nexo_test_app.dart';

Color? _labelColor(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!.color;

void main() {
  group('botões destrutivos (A6)', () {
    for (final dark in [false, true]) {
      final colors = dark ? NexoColors.dark : NexoColors.light;
      final theme = dark ? 'escuro' : 'claro';

      testWidgets('High: OnError sobre Error ($theme)', (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          nexoTestApp(
            NexoButton.destructiveHigh(
              label: 'Excluir',
              onPressed: () => taps++,
            ),
            dark: dark,
          ),
        );
        expect(_labelColor(tester, 'Excluir'), colors.onError);
        await tester.tap(find.text('Excluir'));
        expect(taps, 1);
      });

      testWidgets('Low: texto Error, ícone Icon/Error ($theme)', (
        tester,
      ) async {
        await tester.pumpWidget(
          nexoTestApp(
            NexoButton.destructiveLow(
              label: 'Excluir disciplina',
              leadingIcon: LucideIcons.trash2,
              onPressed: () {},
            ),
            dark: dark,
          ),
        );
        expect(_labelColor(tester, 'Excluir disciplina'), colors.error);
        expect(
          tester.widget<Icon>(find.byIcon(LucideIcons.trash2)).color,
          colors.iconError,
        );
      });
    }

    testWidgets('desabilitados usam Disabled e não respondem', (tester) async {
      await tester.pumpWidget(
        nexoTestApp(
          const Column(
            children: [
              NexoButton.destructiveHigh(label: 'Alto', onPressed: null),
              NexoButton.destructiveLow(label: 'Baixo', onPressed: null),
            ],
          ),
        ),
      );
      expect(_labelColor(tester, 'Alto'), NexoColors.light.disabledContent);
      expect(_labelColor(tester, 'Baixo'), NexoColors.light.disabledContent);
      expect(
        tester.getSemantics(find.text('Baixo')),
        isSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          label: 'Baixo',
        ),
      );
    });

    testWidgets('Dialog destrutivo confirma com o Destructive/High', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        nexoTestApp(
          Builder(
            builder: (context) => NexoButton.primary(
              label: 'Abrir',
              onPressed: () async => result = await showNexoDialog(
                context,
                title: 'Excluir conta?',
                message: 'Seus dados serão apagados.',
                confirmLabel: 'Excluir conta',
                destructive: true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(NexoButton, 'Excluir conta'), findsOneWidget);
      expect(
        tester
            .widget<NexoButton>(
              find.widgetWithText(NexoButton, 'Excluir conta'),
            )
            .variant,
        NexoButtonVariant.destructiveHigh,
      );
      await tester.tap(find.text('Excluir conta'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  test('tokens de pulso (Motion/Duration/Pulse e Opacity/PulseMin)', () {
    const motion = NexoMotion.standardMotion;
    expect(motion.pulse, const Duration(milliseconds: 1050));
    expect(motion.pulseMinOpacity, 0.55);
    final copy = motion.copyWith(pulse: const Duration(milliseconds: 10));
    expect(copy.pulse, const Duration(milliseconds: 10));
    expect(copy.pulseMinOpacity, 0.55);
  });
}
