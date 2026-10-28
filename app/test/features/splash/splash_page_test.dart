import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/app/startup/app_startup.dart';
import 'package:nexo/core/data/local_flags.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/brand/nexo_animated_symbol.dart';
import 'package:nexo/features/splash/application/splash_providers.dart';
import 'package:nexo/features/splash/presentation/splash_page.dart';

Future<ProviderContainer> _pumpSplash(
  WidgetTester tester, {
  required LocalFlags flags,
  bool reduceMotion = false,
  Future<void> Function()? startup,
}) async {
  final container = ProviderContainer(
    overrides: [
      localFlagsProvider.overrideWithValue(flags),
      if (startup != null) appStartupProvider.overrideWith((ref) => startup()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: NexoTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: const SplashPage(),
        ),
      ),
    ),
  );
  return container;
}

NexoAnimatedSymbol _symbol(WidgetTester tester) =>
    tester.widget<NexoAnimatedSymbol>(find.byType(NexoAnimatedSymbol));

void main() {
  testWidgets('1ª abertura: desenha, mostra as boas-vindas e grava a marca', (
    tester,
  ) async {
    final flags = InMemoryLocalFlags();
    final container = await _pumpSplash(tester, flags: flags);

    // Começa vazio e o traço reto vem antes do curvo.
    expect(_symbol(tester).straight, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_symbol(tester).straight, greaterThan(0));
    expect(_symbol(tester).curve, 0);

    expect(find.text('Bem-vindo ao Nexo'), findsOneWidget);
    expect(find.text('Do objetivo à ação do dia.'), findsOneWidget);
    expect(container.read(splashFinishedProvider), isFalse);

    // Desenho e texto até 1,5 s + pausa de 1,2 s + ~600 ms de leitura.
    await tester.pump(const Duration(milliseconds: 3000));
    expect(container.read(splashFinishedProvider), isFalse);
    await tester.pumpAndSettle();
    await tester.pump();
    expect(_symbol(tester).straight, 1);
    expect(_symbol(tester).curve, 1);
    expect(flags.firstOpenDone, isTrue);
    expect(container.read(splashFinishedProvider), isTrue);
  });

  testWidgets(
    'aberturas seguintes: só a logo, desenha em 1,5 s e sai em 2,7 s',
    (tester) async {
      final container = await _pumpSplash(
        tester,
        flags: InMemoryLocalFlags(firstOpenDone: true),
      );
      expect(find.text('Bem-vindo ao Nexo'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(_symbol(tester).straight, closeTo(1, 1e-3));
      expect(_symbol(tester).curve, closeTo(1, 1e-3));
      expect(container.read(splashFinishedProvider), isFalse);

      await tester.pump(const Duration(milliseconds: 1150));
      expect(container.read(splashFinishedProvider), isFalse);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(container.read(splashFinishedProvider), isTrue);
    },
  );

  testWidgets('espera a carga inicial terminar, mesmo com a animação pronta', (
    tester,
  ) async {
    final startup = Completer<void>();
    final container = await _pumpSplash(
      tester,
      flags: InMemoryLocalFlags(firstOpenDone: true),
      startup: () => startup.future,
    );
    await tester.pumpAndSettle();
    expect(container.read(splashFinishedProvider), isFalse);

    startup.complete();
    await tester.pump();
    expect(container.read(splashFinishedProvider), isTrue);
  });

  testWidgets('erro na carga inicial é registrado e não prende na splash', (
    tester,
  ) async {
    final container = await _pumpSplash(
      tester,
      flags: InMemoryLocalFlags(firstOpenDone: true),
      startup: () async => throw StateError('falha simulada'),
    );
    await tester.pumpAndSettle();
    await tester.pump();
    expect(tester.takeException(), isA<StateError>());
    expect(container.read(splashFinishedProvider), isTrue);
  });

  testWidgets('reduzir movimento: símbolo inteiro desde o início e sai já', (
    tester,
  ) async {
    final container = await _pumpSplash(
      tester,
      flags: InMemoryLocalFlags(firstOpenDone: true),
      reduceMotion: true,
    );
    expect(_symbol(tester).straight, 1);
    expect(_symbol(tester).curve, 1);
    await tester.pump();
    await tester.pump();
    expect(container.read(splashFinishedProvider), isTrue);
  });

  testWidgets('reduzir movimento na 1ª abertura: texto estático + leitura', (
    tester,
  ) async {
    final container = await _pumpSplash(
      tester,
      flags: InMemoryLocalFlags(),
      reduceMotion: true,
    );
    final opacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.text('Bem-vindo ao Nexo'),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(splashFinishedProvider), isFalse);
    await tester.pumpAndSettle();
    await tester.pump();
    expect(container.read(splashFinishedProvider), isTrue);
  });

  testWidgets('o símbolo tem nome acessível', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpSplash(tester, flags: InMemoryLocalFlags(firstOpenDone: true));
    expect(find.bySemanticsLabel('Nexo'), findsOneWidget);
    await tester.pumpAndSettle();
    handle.dispose();
  });
}
