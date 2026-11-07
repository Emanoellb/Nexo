import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/data/local_flags.dart';
import 'package:nexo/core/ui/ui.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/data/fake_auth_repository.dart';
import 'package:nexo/features/auth/domain/auth_user.dart';
import 'package:nexo/features/home/presentation/home_page.dart';

const _user = AuthUser(
  uid: 'nova',
  emailVerified: true,
  email: 'nova.conta@email.com',
);
final _home = find.byType(HomePage);
const _titles = [
  'Objetivo e plano',
  'Tarefas e calendário',
  'Seu dia no Início',
  'Sessão de foco',
  'Seu progresso',
];

/// App logo depois do primeiro cadastro: perfil sem `tutorialSeen`.
Future<FakeUserProfileRepository> _pumpTutorial(
  WidgetTester tester, {
  Size size = const Size(1080, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final profiles = FakeUserProfileRepository(
    profiles: {_user.uid: const UserProfile(displayName: 'Ana')},
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(initialUser: _user),
        ),
        userProfileRepositoryProvider.overrideWithValue(profiles),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 28, 12)),
        localFlagsProvider.overrideWithValue(
          InMemoryLocalFlags(firstOpenDone: true),
        ),
      ],
      child: const NexoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return profiles;
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(NexoButton, label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('5 passos, "Tudo pronto" e "Começar" leva ao Início', (
    tester,
  ) async {
    final profiles = await _pumpTutorial(tester);
    expect(find.text('Boas-vindas, Ana'), findsOneWidget);

    for (var i = 0; i < _titles.length; i++) {
      expect(find.text(_titles[i]), findsOneWidget, reason: 'passo ${i + 1}');
      expect(find.bySemanticsLabel('Passo ${i + 1} de 5'), findsOneWidget);
      await _tapButton(tester, 'Próximo');
    }

    expect(find.text('Tudo pronto'), findsOneWidget);
    expect(
      find.text('Seu objetivo e a ação do dia, no mesmo lugar.'),
      findsOneWidget,
    );
    // No fechamento: só o símbolo, sem "Pular" e sem os pontos.
    expect(find.widgetWithText(NexoButton, 'Pular'), findsNothing);
    expect(find.byType(NexoPageControl), findsNothing);
    expect(find.byType(NexoWordmark), findsNothing);

    await _tapButton(tester, 'Começar');
    expect(_home, findsOneWidget);
    expect(
      (await profiles.watchProfile(_user.uid).first)!.tutorialSeen,
      isTrue,
    );
  });

  testWidgets('"Pular" leva ao "Tudo pronto"', (tester) async {
    await _pumpTutorial(tester);
    await _tapButton(tester, 'Pular');
    expect(find.text('Tudo pronto'), findsOneWidget);
    expect(find.text('Objetivo e plano'), findsNothing);
  });

  testWidgets('"Começar" só aparece depois da animação do "Tudo pronto"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpTutorial(tester);
    await tester.tap(find.widgetWithText(NexoButton, 'Pular'));
    // Troca de página + parte da animação: ainda sem o "Começar".
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Tudo pronto'), findsOneWidget);
    final fade = find.ancestor(
      of: find.widgetWithText(NexoButton, 'Começar'),
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(fade).opacity, 0);
    expect(find.bySemanticsLabel('Começar'), findsNothing);

    // Fim da animação (o atraso inicial é um timer: avança o relógio).
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(fade).opacity, 1);
    expect(find.bySemanticsLabel('Começar'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('com "reduzir movimento", "Começar" aparece direto', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpTutorial(tester);
    await tester.tap(find.widgetWithText(NexoButton, 'Pular'));
    await tester.pump();
    await tester.pump();
    final fade = find.ancestor(
      of: find.widgetWithText(NexoButton, 'Começar'),
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(fade).opacity, 1);
  });

  testWidgets('deslizar e o voltar do Android trocam de passo', (tester) async {
    await _pumpTutorial(tester);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text(_titles[1]), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(_titles[0]), findsOneWidget);
  });

  testWidgets('"Voltar" some no 1º passo e volta um passo', (tester) async {
    await _pumpTutorial(tester);
    expect(find.widgetWithText(NexoButton, 'Voltar'), findsNothing);

    await _tapButton(tester, 'Próximo');
    await _tapButton(tester, 'Próximo');
    expect(find.text(_titles[2]), findsOneWidget);

    await _tapButton(tester, 'Voltar');
    expect(find.text(_titles[1]), findsOneWidget);
  });

  testWidgets('"Repetir animação" só existe com animação', (tester) async {
    await _pumpTutorial(tester);
    expect(find.byTooltip('Repetir animação'), findsOneWidget);
    await tester.tap(find.byTooltip('Repetir animação'));
    await tester.pumpAndSettle();
    expect(find.text(_titles[0]), findsOneWidget);
  });

  testWidgets('com "reduzir movimento", sem o botão de repetir', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpTutorial(tester);
    expect(find.byTooltip('Repetir animação'), findsNothing);
  });

  testWidgets('tela pequena com fonte ampliada não estoura', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpTutorial(tester, size: const Size(1080, 1920));
    for (var i = 0; i < _titles.length; i++) {
      await _tapButton(tester, 'Próximo');
    }
    expect(find.text('Tudo pronto'), findsOneWidget);
  });
}
