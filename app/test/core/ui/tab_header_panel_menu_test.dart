import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/ui.dart';

import '../../helpers/nexo_test_app.dart';

/// Topo das abas, painel de notificações e menu do "+" (aprovados no Pen.dev
/// em 04/11/2026).
void main() {
  group('NexoTabHeader', () {
    Widget header({int unread = 0, VoidCallback? onProfile}) => MaterialApp(
      theme: NexoTheme.light(),
      home: Scaffold(
        body: NexoTabHeader(
          title: 'Início',
          unreadCount: unread,
          onNotifications: () {},
          initials: 'AS',
          onProfile: onProfile ?? () {},
        ),
      ),
    );

    testWidgets('nome da aba, sino e avatar com as iniciais', (tester) async {
      await tester.pumpWidget(header());
      expect(find.text('Início'), findsOneWidget);
      expect(find.byIcon(LucideIcons.bell), findsOneWidget);
      expect(find.text('AS'), findsOneWidget);
      expect(
        tester.getSize(find.byType(NexoTabHeader)).height,
        greaterThanOrEqualTo(NexoTabHeader.height),
      );
    });

    testWidgets('sino diz quantos não lidos; ponto só com não lido', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(header());
      expect(find.bySemanticsLabel('Notificações'), findsOneWidget);

      await tester.pumpWidget(header(unread: 2));
      expect(
        find.bySemanticsLabel('Notificações, 2 não lidas'),
        findsOneWidget,
      );
      final dot = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color == NexoColors.light.error);
      expect(dot, hasLength(1));
      handle.dispose();
    });

    testWidgets('avatar é um botão "Perfil"', (tester) async {
      final handle = tester.ensureSemantics();
      var opened = 0;
      await tester.pumpWidget(header(onProfile: () => opened++));
      await tester.tap(find.bySemanticsLabel('Perfil'));
      expect(opened, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    group('saudação do Início', () {
      Widget greeted(String name, {double width = 360, bool dark = false}) =>
          MaterialApp(
            theme: dark ? NexoTheme.dark() : NexoTheme.light(),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: NexoTabHeader(
                    title: 'Início',
                    greeting: greetingOf(name),
                    unreadCount: 0,
                    onNotifications: () {},
                    initials: initialsOf(name),
                    onProfile: () {},
                  ),
                ),
              ),
            ),
          );

      test('"Olá" fixo e só o primeiro nome; sem nome, só "Olá"', () {
        expect(greetingOf('Ana Souza'), 'Olá, Ana');
        expect(greetingOf('  Ana  '), 'Olá, Ana');
        expect(greetingOf(''), 'Olá');
        expect(greetingOf('   '), 'Olá');
      });

      for (final dark in [false, true]) {
        testWidgets('duas linhas nos 64, lidas como um cabeçalho '
            '(${dark ? 'escuro' : 'claro'})', (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(greeted('Ana Souza', dark: dark));
          final colors = dark ? NexoColors.dark : NexoColors.light;
          final hello = tester.widget<Text>(find.text('Olá, Ana'));
          final tab = tester.widget<Text>(find.text('Início'));
          final theme = dark ? NexoTheme.dark() : NexoTheme.light();
          expect(hello.style!.fontSize, theme.textTheme.titleLarge!.fontSize);
          expect(hello.style!.color, colors.onSurface);
          expect(tab.style!.fontSize, theme.textTheme.bodyMedium!.fontSize);
          expect(tab.style!.color, colors.onSurfaceVariant);
          expect(
            tester.getSize(find.byType(NexoTabHeader)).height,
            NexoTabHeader.height,
          );
          expect(
            tester.getSemantics(find.bySemanticsLabel('Olá, Ana. Início')),
            isSemantics(isHeader: true, label: 'Olá, Ana. Início'),
          );
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }

      testWidgets('sem nome no perfil: "Olá. Início"', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(greeted(''));
        expect(find.text('Olá'), findsOneWidget);
        expect(find.bySemanticsLabel('Olá. Início'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('nome longo em 2,0 corta com reticências, sem estourar', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(greeted('Maximiliana Escolástica'));
        expect(tester.takeException(), isNull);
        final hello = tester.widget<Text>(find.text('Olá, Maximiliana'));
        expect(hello.maxLines, 1);
        expect(hello.overflow, TextOverflow.ellipsis);
        // O sino e o avatar continuam inteiros.
        expect(
          tester.getSize(find.bySemanticsLabel('Perfil')).width,
          greaterThanOrEqualTo(48),
        );
      });
    });
  });

  group('NexoNotificationPanel', () {
    Widget panel({List<Widget> items = const [], VoidCallback? markAll}) =>
        nexoTestApp(
          NexoNotificationPanel(
            items: items,
            onMarkAllRead: markAll,
            onClose: () {},
          ),
        );

    NexoNotificationItem item(String title, {bool unread = false}) =>
        NexoNotificationItem(
          icon: LucideIcons.calendarClock,
          title: title,
          body: 'Lista de exercícios 3 · Cálculo II · amanhã, 18:00',
          time: 'há 2 h',
          unread: unread,
          onTap: () {},
        );

    testWidgets('vazio: sino e "Nenhuma notificação recente"', (tester) async {
      await tester.pumpWidget(panel());
      expect(find.text('Notificações'), findsOneWidget);
      expect(find.text('Últimos 30 dias'), findsOneWidget);
      expect(find.text('Nenhuma notificação recente'), findsOneWidget);
      expect(
        tester
            .widget<NexoIconButton>(
              find.widgetWithIcon(NexoIconButton, LucideIcons.checkCheck),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('não lido: título 600, ponto e fundo próprio', (tester) async {
      await tester.pumpWidget(
        panel(
          items: [item('Entrega amanhã', unread: true), item('Meta do dia')],
          markAll: () {},
        ),
      );
      final c = NexoColors.light;
      TextStyle styleOf(String t) => tester.widget<Text>(find.text(t)).style!;
      expect(styleOf('Entrega amanhã').fontVariations, [
        const FontVariation.weight(600),
      ]);
      expect(styleOf('Meta do dia').fontVariations, [
        const FontVariation.weight(500),
      ]);
      final unreadDots = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color == c.primary && d.shape == BoxShape.circle);
      expect(unreadDots, hasLength(1));
    });

    testWidgets('cartão a SM do topo; seta emendada (1 px sobre a borda)', (
      tester,
    ) async {
      await tester.pumpWidget(panel());
      final panelRect = tester.getRect(find.byType(NexoNotificationPanel));
      final arrow = tester.getRect(
        find
            .descendant(
              of: find.byType(NexoNotificationPanel),
              matching: find.byType(CustomPaint),
            )
            .last,
      );
      final card = tester.getRect(
        find
            .descendant(
              of: find.byType(NexoNotificationPanel),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(card.top - panelRect.top, NexoSpacing.standard.sm);
      expect(arrow.size, NexoNotificationPanel.arrowSize);
      expect(arrow.bottom - card.top, 1);
    });

    testWidgets('lista com até 400 de altura e rolagem', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        panel(items: [for (var i = 0; i < 12; i++) item('Aviso $i')]),
      );
      final list = tester.getSize(find.byType(ListView));
      expect(
        list.height,
        lessThanOrEqualTo(NexoNotificationPanel.maxListHeight),
      );
    });

    testWidgets('diretrizes de alvo, rótulo e contraste', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        panel(items: [item('Entrega amanhã', unread: true)], markAll: () {}),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  group('showNexoFabMenu', () {
    Future<List<String>> openMenu(WidgetTester tester) async {
      final chosen = <String>[];
      final fabKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: NexoTheme.light(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: Builder(
                builder: (context) => NexoFab(
                  key: fabKey,
                  onPressed: () {
                    final box =
                        fabKey.currentContext!.findRenderObject()! as RenderBox;
                    showNexoFabMenu(
                      context,
                      fabRect: box.localToGlobal(Offset.zero) & box.size,
                      options: [
                        for (final label in ['Nova tarefa', 'Novo plano'])
                          NexoFabMenuOption(
                            icon: LucideIcons.listTodo,
                            label: label,
                            onSelected: () => chosen.add(label),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(NexoFab));
      await tester.pumpAndSettle();
      return chosen;
    }

    testWidgets('abre as opções acima do "+", que vira "Fechar menu"', (
      tester,
    ) async {
      await openMenu(tester);
      expect(find.text('Nova tarefa'), findsOneWidget);
      expect(find.text('Novo plano'), findsOneWidget);
      expect(find.byIcon(LucideIcons.x), findsOneWidget);
      final fab = tester.getTopLeft(find.byIcon(LucideIcons.x));
      expect(tester.getTopLeft(find.text('Novo plano')).dy, lessThan(fab.dy));
      expect(
        tester.getTopLeft(find.text('Nova tarefa')).dy,
        lessThan(tester.getTopLeft(find.text('Novo plano')).dy),
      );
    });

    testWidgets('escolher fecha o menu e avisa a opção', (tester) async {
      final chosen = await openMenu(tester);
      await tester.tap(find.text('Novo plano'));
      await tester.pumpAndSettle();
      expect(chosen, ['Novo plano']);
      expect(find.text('Nova tarefa'), findsNothing);
    });

    testWidgets('fecha pelo X, pelo voltar e com toque fora', (tester) async {
      await openMenu(tester);
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
      expect(find.text('Nova tarefa'), findsNothing);

      await tester.tap(find.byType(NexoFab));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Nova tarefa'), findsNothing);

      await tester.tap(find.byType(NexoFab));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('Nova tarefa'), findsNothing);
    });

    testWidgets('com "reduzir movimento", abre sem animação', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await openMenu(tester);
      expect(find.text('Nova tarefa'), findsOneWidget);
    });
  });
}
