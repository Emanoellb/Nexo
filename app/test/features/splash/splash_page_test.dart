import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/local_flags.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/brand/nexo_animated_symbol.dart';
import 'package:nexo/features/splash/application/splash_providers.dart';
import 'package:nexo/features/splash/presentation/splash_page.dart';

Future<ProviderContainer> _pumpSplash(
  WidgetTester tester, {
  required LocalFlags flags,
  bool reduceMotion = false,
}) async {
  final container = ProviderContainer(
    overrides: [localFlagsProvider.overrideWithValue(flags)],
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

    // Desenho (700 ms) + texto até 750 ms + ~600 ms de leitura.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(container.read(splashFinishedProvider), isFalse);
    await tester.pumpAndSettle();
    expect(_symbol(tester).straight, 1);
    expect(_symbol(tester).curve, 1);
    expect(flags.firstOpenDone, isTrue);
    expect(container.read(splashFinishedProvider), isTrue);
  });

  testWidgets('aberturas seguintes: só a logo, termina em 700 ms', (
    tester,
  ) async {
    final container = await _pumpSplash(
      tester,
      flags: InMemoryLocalFlags(firstOpenDone: true),
    );
    expect(find.text('Bem-vindo ao Nexo'), findsNothing);

    await tester.pump(const Duration(milliseconds: 650));
    expect(container.read(splashFinishedProvider), isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
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
