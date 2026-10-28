import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/ui.dart';

import '../../helpers/nexo_test_app.dart';

const _rule =
    'Mínimo de 8 caracteres, com letra maiúscula, letra minúscula, número e '
    'caractere especial.';

void main() {
  group('NexoTextField', () {
    testWidgets('mostra rótulo acima e texto de apoio', (tester) async {
      await tester.pumpWidget(
        nexoTestApp(const NexoTextField(label: 'Senha', helperText: _rule)),
      );
      expect(find.text('Senha'), findsOneWidget);
      expect(find.text(_rule), findsOneWidget);
      final labelY = tester.getTopLeft(find.text('Senha')).dy;
      final fieldY = tester.getTopLeft(find.byType(TextField)).dy;
      expect(labelY, lessThan(fieldY));
    });

    testWidgets('erro troca o texto de apoio e mostra o ícone', (tester) async {
      await tester.pumpWidget(
        nexoTestApp(
          const NexoTextField(
            label: 'Senha',
            helperText: _rule,
            errorText: 'Crie uma senha.',
          ),
        ),
      );
      expect(find.text(_rule), findsNothing);
      final error = tester.widget<Text>(find.text('Crie uma senha.'));
      expect(error.style!.color, NexoColors.light.error);
      expect(find.byIcon(LucideIcons.circleAlert), findsOneWidget);
    });

    testWidgets('campo com ação própria mantém a ação no erro', (tester) async {
      await tester.pumpWidget(
        nexoTestApp(
          const NexoTextField(
            label: 'Senha',
            obscurable: true,
            errorText: 'Crie uma senha.',
          ),
        ),
      );
      expect(find.byIcon(LucideIcons.circleAlert), findsNothing);
      expect(find.byTooltip('Mostrar senha'), findsOneWidget);
      expect(find.text('Crie uma senha.'), findsOneWidget);
    });

    testWidgets('data com erro mantém o calendário', (tester) async {
      await tester.pumpWidget(
        nexoTestApp(
          NexoDateField(
            label: 'Data de nascimento',
            controller: TextEditingController(text: '14/05/2011'),
            firstDate: DateTime(1900),
            lastDate: DateTime(2026, 10, 27),
            errorText: 'Você precisa ter 16 anos ou mais para usar o Nexo.',
          ),
        ),
      );
      expect(find.byIcon(LucideIcons.circleAlert), findsNothing);
      expect(find.byTooltip('Abrir calendário'), findsOneWidget);
    });

    testWidgets('senha começa oculta e o botão alterna', (tester) async {
      await tester.pumpWidget(
        nexoTestApp(const NexoTextField(label: 'Senha', obscurable: true)),
      );
      bool obscured() =>
          tester.widget<EditableText>(find.byType(EditableText)).obscureText;

      expect(obscured(), isTrue);
      expect(find.byTooltip('Mostrar senha'), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.eye));
      await tester.pump();
      expect(obscured(), isFalse);
      expect(find.byTooltip('Ocultar senha'), findsOneWidget);
    });

    testWidgets('somente leitura mostra o cadeado e não edita', (tester) async {
      await tester.pumpWidget(
        nexoTestApp(const NexoTextField(label: 'E-mail', readOnly: true)),
      );
      expect(find.byIcon(LucideIcons.lockKeyhole), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    });

    testWidgets('campo tem pelo menos 48 px de altura', (tester) async {
      await tester.pumpWidget(
        nexoTestApp(const NexoTextField(label: 'E-mail')),
      );
      expect(
        tester.getSize(find.byType(TextField)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('leitor de tela recebe o rótulo junto com o campo', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        nexoTestApp(
          const NexoTextField(label: 'E-mail', hintText: 'voce@email.com'),
        ),
      );
      expect(find.bySemanticsLabel(RegExp('E-mail')), findsOneWidget);
      handle.dispose();
    });
  });
}
