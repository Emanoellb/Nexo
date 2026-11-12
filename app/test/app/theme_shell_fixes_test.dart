import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/features/calendar/presentation/agenda_page.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/app/window_background.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/ui.dart';
import 'package:nexo/features/home/presentation/home_page.dart';

import '../fakes/fakes.dart';

/// Correções do code review da feat/tema-escuro (04/11/2026).
Future<void> _pumpReady(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...fakeBackend(
          auth: FakeAuthRepository.signedIn(),
          profiles: FakeUserProfileRepository.prototype(),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 4, 12)),
      ],
      child: const NexoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Avisa o shell de uma lista a partir de [context]: longa (conteúdo abaixo
/// da barra) ou curta (cabe na tela).
void _reportList(BuildContext context, {bool long = true}) {
  ScrollMetricsNotification(
    metrics: FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: long ? 800 : 0,
      pixels: 0,
      viewportDimension: 600,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 3,
    ),
    context: context,
  ).dispatch(context);
}

bool _overContent(WidgetTester tester) =>
    tester.widget<NexoBottomBar>(find.byType(NexoBottomBar)).overContent;

void main() {
  testWidgets('barra de status por tema, sem pintar a barra de navegação', (
    tester,
  ) async {
    await _pumpReady(tester);
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
    );
    expect(region.value.statusBarIconBrightness, Brightness.dark);
    expect(region.value.systemNavigationBarColor, isNull);
    expect(region.value.systemNavigationBarIconBrightness, isNull);
  });

  testWidgets('vidro: só a aba visível conta', (tester) async {
    await _pumpReady(tester);
    // Abre a Agenda uma vez (monta a aba) e volta ao Início.
    await tester.tap(find.byIcon(LucideIcons.calendarDays));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.house));
    await tester.pumpAndSettle();
    // O Início (aba visível) com a lista inteira na tela: repouso.
    final home = tester.element(find.byType(HomePage));
    _reportList(home, long: false);
    await tester.pump();
    expect(_overContent(tester), isFalse);

    // A Agenda, fora da tela, avisa uma lista longa (ex.: teclado, rotação).
    _reportList(tester.element(find.byType(AgendaPage, skipOffstage: false)));
    await tester.pump();
    expect(_overContent(tester), isFalse);

    // A aba visível avisando liga o vidro.
    _reportList(home);
    await tester.pump();
    expect(_overContent(tester), isTrue);
  });

  testWidgets('fundo da janela nativa segue o Surface do tema ativo', (
    tester,
  ) async {
    const channel = MethodChannel('nexo/window');
    final sent = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'setBackgroundColor') sent.add(call.arguments);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    Widget app(ThemeMode mode) => MaterialApp(
      theme: NexoTheme.light(),
      darkTheme: NexoTheme.dark(),
      themeMode: mode,
      builder: (context, child) => WindowBackgroundSync(child: child!),
      home: const SizedBox(),
    );

    await tester.pumpWidget(app(ThemeMode.dark));
    await tester.pumpAndSettle();
    expect(sent.last, NexoColors.dark.surface.toARGB32());

    await tester.pumpWidget(app(ThemeMode.light));
    await tester.pumpAndSettle();
    expect(sent.last, NexoColors.light.surface.toARGB32());

    // Mesmo tema: não reenvia.
    final count = sent.length;
    await tester.pumpWidget(app(ThemeMode.light));
    await tester.pumpAndSettle();
    expect(sent, hasLength(count));
  });
}
