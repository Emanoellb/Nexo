import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/ui/ui.dart';

import '../helpers/nexo_test_app.dart';

import '../fakes/fakes.dart';

/// Diretrizes de alvo (48), rótulo e contraste (WCAG AA) em campos,
/// checkbox, alerta e telas de entrada, nos temas claro e escuro
/// (auditoria de componentes; modo escuro de 04/11/2026).
Future<void> _meetsGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  for (final dark in [false, true]) {
    final theme = dark ? 'escuro' : 'claro';

    group('componentes ($theme)', () {
      testWidgets('campos: normal, com apoio, com erro e de data', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          nexoTestApp(
            SingleChildScrollView(
              child: Column(
                children: [
                  const NexoTextField(
                    label: 'E-mail',
                    hintText: 'voce@exemplo.com',
                  ),
                  const NexoTextField(
                    label: 'Senha',
                    obscurable: true,
                    helperText: 'Mínimo de 8 caracteres.',
                  ),
                  const NexoTextField(
                    label: 'Nome',
                    errorText: 'Informe seu nome.',
                  ),
                  NexoDateField(
                    label: 'Data de nascimento',
                    controller: TextEditingController(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2026, 11, 4),
                  ),
                ],
              ),
            ),
            dark: dark,
          ),
        );
        await _meetsGuidelines(tester);
        handle.dispose();
      });

      testWidgets('checkbox marcado e desmarcado', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          nexoTestApp(
            Column(
              children: [
                NexoCheckbox(
                  value: true,
                  labelText: 'Li e aceito os Termos de Uso',
                  onChanged: (_) {},
                ),
                NexoCheckbox(
                  value: false,
                  labelText: 'Lembretes',
                  onChanged: (_) {},
                ),
              ],
            ),
            dark: dark,
          ),
        );
        await _meetsGuidelines(tester);
        handle.dispose();
      });

      testWidgets('alerta nos 4 tons, com ação', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          nexoTestApp(
            SingleChildScrollView(
              child: Column(
                children: [
                  for (final tone in NexoAlertTone.values)
                    NexoAlert(
                      tone: tone,
                      title: 'Título ${tone.name}',
                      message: 'Mensagem do alerta.',
                      actionLabel: 'Tentar de novo',
                      onAction: () {},
                    ),
                ],
              ),
            ),
            dark: dark,
          ),
        );
        await _meetsGuidelines(tester);
        handle.dispose();
      });
    });

    group('telas de entrada ($theme)', () {
      Future<void> pumpEntry(WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...fakeBackend(
                auth: FakeAuthRepository(withPrototypeAccounts: true),
                profiles: FakeUserProfileRepository.prototype(),
                flags: InMemoryLocalFlags(
                  firstOpenDone: true,
                  themePreference: dark ? 'dark' : 'light',
                ),
              ),
              clockProvider.overrideWithValue(() => DateTime(2026, 11, 4, 12)),
            ],
            child: const NexoApp(),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> tap(WidgetTester tester, Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      testWidgets('Login, com os erros dos campos', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpEntry(tester);
        expect(
          Theme.of(tester.element(find.text('Entre na sua conta'))).brightness,
          dark ? Brightness.dark : Brightness.light,
        );
        await _meetsGuidelines(tester);

        await tap(tester, find.widgetWithText(NexoButton, 'Entrar'));
        await _meetsGuidelines(tester);
        handle.dispose();
      });

      testWidgets('Cadastro', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpEntry(tester);
        await tap(tester, find.text('Criar conta'));
        await _meetsGuidelines(tester);
        handle.dispose();
      });

      testWidgets('Redefinir senha', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpEntry(tester);
        await tap(tester, find.text('Esqueci minha senha'));
        await _meetsGuidelines(tester);
        handle.dispose();
      });
    });
  }
}
