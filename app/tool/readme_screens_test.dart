// Gera as imagens do README (vitrine do Nexo), fora da suíte normal: fica
// em tool/, não em test/, então o `flutter test` não roda este arquivo.
//
// Gerar (a partir de app/):
//   flutter test --update-goldens tool/readme_screens_test.dart
//
// As telas são as reais, com os fakes de test/fakes e dados fictícios
// (conta de protótipo e instituições inventadas, em tool/readme_data.dart).
// O e-mail da conta vira um domínio reservado (ana@exemplo.test) só aqui, por
// override.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/app/router/app_router.dart';
import 'package:nexo/app/router/routes.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/features/auth/domain/auth_user.dart';
import 'package:nexo/features/focus/application/focus_controller.dart';
import 'package:nexo/features/focus/presentation/focus_page.dart';
import 'package:nexo/features/plans/application/plans_providers.dart';

import '../test/fakes/fakes.dart';
import '../test/helpers/nexo_test_app.dart';
import 'readme_data.dart';

/// Quarta, 11/11/2026, 10:00 (os exemplos são relativos a hoje).
final _start = DateTime(2026, 11, 11, 10);
var _now = _start;

/// Conta Ana com um e-mail de domínio reservado: nenhum e-mail real nas
/// imagens.
const _ana = AuthUser(
  uid: FakeAuthRepository.prototypeUserUid,
  emailVerified: true,
  email: 'ana@exemplo.test',
);

/// Celular de 390 × 844 dp, PNG em escala 2 (780 × 1688).
Future<void> _pumpApp(
  WidgetTester tester, {
  required bool dark,
  bool signedIn = true,
}) async {
  _now = _start;
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...fakeBackend(
          auth: signedIn
              ? FakeAuthRepository(initialUser: _ana)
              : FakeAuthRepository(),
          flags: InMemoryLocalFlags(
            firstOpenDone: true,
            themePreference: dark ? 'dark' : 'light',
            firstStepsDoneFor: {FakeAuthRepository.prototypeUserUid},
          ),
        ),
        clockProvider.overrideWithValue(() => _now),
        // Dados da vitrine (tool/readme_data.dart) no lugar dos exemplos.
        prototypeSampleDataProvider.overrideWith(seedReadmeData),
        // Tela cheia do Foco desligada: as ações aparecem na imagem.
        focusImmersiveProvider.overrideWithValue(false),
      ],
      child: const NexoApp(),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(NexoApp)),
  );
  container.listen(prototypeSampleDataProvider, (_, _) {});
  await tester.pumpAndSettle();
  await container.read(prototypeSampleDataProvider.future);
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(NexoApp)));

GoRouter _router(WidgetTester tester) =>
    _container(tester).read(routerProvider);

Future<void> _go(WidgetTester tester, String location) async {
  _router(tester).go(location);
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  // Sem Snackbar de ações anteriores na imagem.
  for (final messenger in tester.stateList<ScaffoldMessengerState>(
    find.byType(ScaffoldMessenger),
  )) {
    messenger.clearSnackBars();
  }
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(NexoApp),
    matchesGoldenFile('../../.github/readme/$name.png'),
  );
}

void main() {
  setUpAll(loadNexoFonts);

  for (final dark in [false, true]) {
    final theme = dark ? 'escuro' : 'claro';

    testWidgets('login · $theme', (tester) async {
      await _pumpApp(tester, dark: dark, signedIn: false);
      await _shot(tester, 'login-$theme');
    });

    testWidgets('início · $theme', (tester) async {
      await _pumpApp(tester, dark: dark);
      await _go(tester, AppRoutes.home);
      await _shot(tester, 'inicio-$theme');
    });

    testWidgets('tarefas · $theme', (tester) async {
      await _pumpApp(tester, dark: dark);
      await _go(tester, AppRoutes.tasks);
      await _shot(tester, 'tarefas-$theme');
    });

    testWidgets('agenda · $theme', (tester) async {
      await _pumpApp(tester, dark: dark);
      await _go(tester, AppRoutes.calendar);
      await _shot(tester, 'agenda-$theme');
    });

    testWidgets('plano · $theme', (tester) async {
      await _pumpApp(tester, dark: dark);
      final plans = await _container(tester)
          .read(plansRepositoryProvider)
          .watchPlans()
          .first;
      final plan = plans.firstWhere(
        (p) => p.name == 'Concurso Banco Horizonte',
      );
      await _go(tester, AppRoutes.planDetailOf(plan.id));
      await _shot(tester, 'plano-$theme');
    });

    testWidgets('foco · $theme', (tester) async {
      await _pumpApp(tester, dark: dark);
      final plans = await _container(tester)
          .read(plansRepositoryProvider)
          .watchPlans()
          .first;
      final plan = plans.firstWhere(
        (p) => p.name == 'Concurso Banco Horizonte',
      );
      await _container(tester)
          .read(activeFocusProvider.notifier)
          .start(plan.id);
      _router(tester).push(AppRoutes.focus);
      await tester.pumpAndSettle();
      _now = _now.add(const Duration(minutes: 25, seconds: 12));
      await tester.pump(const Duration(seconds: 1));
      await _shot(tester, 'foco-$theme');
    });

    testWidgets('perfil · $theme', (tester) async {
      await _pumpApp(tester, dark: dark);
      _router(tester).push(AppRoutes.profile);
      await tester.pumpAndSettle();
      await _shot(tester, 'perfil-$theme');
    });
  }
}
