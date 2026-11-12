import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/app/router/app_router.dart';
import 'package:nexo/app/router/routes.dart';
import 'package:nexo/core/ui/ui.dart';
import 'package:nexo/features/legal/data/legal_texts.dart';
import 'package:nexo/features/legal/domain/legal_markdown.dart';
import 'package:nexo/features/legal/presentation/legal_document_page.dart';
import 'package:nexo/features/legal/presentation/legal_text.dart';

import '../../fakes/fakes.dart';

/// Texto de exemplo, só para os testes (o app não leva texto de teste).
const _sample = '''
> **RASCUNHO — NÃO PUBLICAR.** Precisa de revisão.

# Termos de Uso do Nexo

**Versão:** 0.3 · **Vigência a partir de:** 01/12/2026

> Nota interna (remover antes de publicar): versão técnica.

<!-- comentário para quem edita -->

## 1. Quem oferece o Nexo

O Nexo é oferecido por **Fulano**, contato
[fulano@exemplo.com](mailto:fulano@exemplo.com), com o campo `displayName`.

Fica eleito o foro de [FORO], sem prejuízo <!-- PENDÊNCIA: o foro --> do
consumidor.

- Primeiro item
  - Item dentro do primeiro
- Segundo item
  com continuação

1. Passo um
2. Passo dois

### 1.1 Dados

| Dado | Para quê |
|---|---|
| Nome | Mostrar no topo |
| E-mail | **Entrar** na conta |

> Leia também a Política de Privacidade.
''';

class _Source implements LegalTextSource {
  const _Source(this.text);

  final String? text;

  @override
  Future<String?> load(LegalDocument document) async => text;
}

/// O app na tela dos Termos (ou da Política, com [privacy]). [source]
/// `null` usa o texto real de `assets/legal/`.
Future<void> _pumpLegal(
  WidgetTester tester, {
  LegalTextSource? source,
  bool privacy = false,
  bool dark = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...fakeBackend(
          auth: FakeAuthRepository(),
          flags: InMemoryLocalFlags(
            firstOpenDone: true,
            themePreference: dark ? 'dark' : 'light',
          ),
        ),
        if (source != null) legalTextSourceProvider.overrideWithValue(source),
      ],
      child: const NexoApp(),
    ),
  );
  await tester.pumpAndSettle();
  final c = ProviderScope.containerOf(tester.element(find.byType(NexoApp)));
  c.read(routerProvider).push(privacy ? AppRoutes.privacy : AppRoutes.terms);
  await tester.pumpAndSettle();
  expect(find.byType(LegalDocumentPage), findsOneWidget);
}

void main() {
  test('o leitor: títulos, parágrafos, listas, tabela, negrito e notas', () {
    final blocks = parseLegalMarkdown(_sample);
    final plain = blocks.map((b) => b.plain).join('\n');
    // O que é interno não entra.
    expect(plain, isNot(contains('RASCUNHO')));
    expect(plain, isNot(contains('Nota interna')));
    expect(plain, isNot(contains('comentário')));
    // O `#` do topo já é o título da tela.
    expect(blocks.whereType<LegalHeading>().map((h) => h.plain), [
      '1. Quem oferece o Nexo',
      '1.1 Dados',
    ]);
    expect(blocks.whereType<LegalHeading>().last.level, 3);

    final first = blocks.whereType<LegalParagraph>().first;
    expect(first.spans.first, const LegalSpan('Versão:', bold: true));
    final second = blocks.whereType<LegalParagraph>().elementAt(1);
    // Link vira o texto dele; código vira texto comum.
    expect(
      second.plain,
      'O Nexo é oferecido por Fulano, contato fulano@exemplo.com, com o '
      'campo displayName.',
    );

    // [FORO] fica como texto; o comentário no meio da linha sai.
    expect(
      blocks.whereType<LegalParagraph>().elementAt(2).plain,
      'Fica eleito o foro de [FORO], sem prejuízo do consumidor.',
    );

    final items = blocks.whereType<LegalListItem>().toList();
    expect(items.map((i) => (i.plain, i.depth, i.number)), [
      ('Primeiro item', 0, null),
      ('Item dentro do primeiro', 1, null),
      ('Segundo item com continuação', 0, null),
      ('Passo um', 0, 1),
      ('Passo dois', 0, 2),
    ]);

    final table = blocks.whereType<LegalTable>().single;
    expect(table.rows, hasLength(2));
    expect(
      table.plain,
      'Dado: Nome; Para quê: Mostrar no topo\nDado: E-mail; Para quê: Entrar '
      'na conta',
    );
    expect(
      blocks.whereType<LegalNote>().single.plain,
      'Leia também a Política de Privacidade.',
    );
  });

  test('os textos de assets/legal leem sem nada interno', () {
    for (final name in ['termos-de-uso.md', 'politica-de-privacidade.md']) {
      final source = File('assets/legal/$name').readAsStringSync();
      final blocks = parseLegalMarkdown(source);
      final plain = blocks.map((b) => b.plain).join('\n');
      expect(blocks.whereType<LegalHeading>(), isNotEmpty, reason: name);
      // A primeira coisa é a versão do próprio documento.
      expect(blocks.first.plain, startsWith('Versão:'), reason: name);
      for (final internal in [
        'NOTA INTERNA',
        'ADVOGADO',
        'PENDÊNCIA',
        'RASCUNHO',
        '<!--',
        '-->',
        '**',
        '`',
      ]) {
        expect(plain, isNot(contains(internal)), reason: '$name: $internal');
      }
    }
    // O foro saiu dos Termos (decisão do usuário, 10/11/2026): nenhum
    // colchete à vista nos dois textos. A regra de mostrar colchetes como
    // texto comum segue coberta pelo texto de exemplo ([FORO]).
    for (final name in ['termos-de-uso.md', 'politica-de-privacidade.md']) {
      final plain = parseLegalMarkdown(
        File('assets/legal/$name').readAsStringSync(),
      ).map((b) => b.plain).join(' ');
      expect(plain, isNot(contains('[')), reason: name);
      expect(plain, isNot(contains('foro')), reason: name);
    }
  });

  testWidgets('sem o texto final, a tela mostra só a versão', (tester) async {
    await _pumpLegal(tester, source: const _Source(null));
    expect(find.text('Termos de Uso'), findsOneWidget);
    expect(
      find.text(
        'O texto completo aparece aqui quando o documento for '
        'publicado.',
      ),
      findsOneWidget,
    );
    expect(find.byType(LegalText), findsNothing);
  });

  testWidgets('com o texto: títulos para o leitor de tela e tabela em blocos', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpLegal(tester, source: const _Source(_sample));
    expect(find.byType(LegalText), findsOneWidget);
    expect(find.textContaining('RASCUNHO'), findsNothing);
    final heading = tester.getSemantics(find.text('1. Quem oferece o Nexo'));
    expect(heading.flagsCollection.isHeader, isTrue);
    // Cada linha da tabela é um cartão com "coluna" e "valor".
    expect(
      find.descendant(
        of: find.byType(LegalText),
        matching: find.byType(NexoCard),
      ),
      findsNWidgets(2),
    );
    expect(find.byType(NexoAlert), findsOneWidget);
    handle.dispose();
  });

  for (final privacy in [false, true]) {
    testWidgets('texto real na tela: versão do documento, títulos e nada '
        'interno · ${privacy ? 'Política' : 'Termos'}', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpLegal(tester, privacy: privacy);
      expect(find.byType(LegalText), findsOneWidget);
      // Só a versão do documento; o id técnico fica para o aceite.
      expect(find.textContaining('Versão vigente'), findsNothing);
      expect(find.textContaining('-2026-11-01'), findsNothing);
      expect(
        find.textContaining('Versão:', findRichText: true),
        findsOneWidget,
      );
      for (final internal in ['NOTA INTERNA', 'ADVOGADO', 'PENDÊNCIA']) {
        expect(find.textContaining(internal, findRichText: true), findsNothing);
      }
      final headings = tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byType(LegalText),
              matching: find.byType(Semantics),
            ),
          )
          .where((s) => s.properties.header ?? false);
      expect(headings, isNotEmpty);
      handle.dispose();
    });
  }

  for (final dark in [false, true]) {
    testWidgets('fonte 2,0, contraste e alvos · ${dark ? 'escuro' : 'claro'}', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpLegal(tester, dark: dark, textScale: 2);
      expect(find.byType(LegalText), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  }
}
