import 'package:flutter/foundation.dart';

/// Um trecho de texto, em negrito ou não.
@immutable
class LegalSpan {
  const LegalSpan(this.text, {this.bold = false});

  final String text;
  final bool bold;

  @override
  bool operator ==(Object other) =>
      other is LegalSpan && other.text == text && other.bold == bold;

  @override
  int get hashCode => Object.hash(text, bold);

  @override
  String toString() => bold ? '**$text**' : text;
}

/// Um bloco do documento.
sealed class LegalBlock {
  const LegalBlock();

  /// O texto corrido (leitor de tela e testes).
  String get plain;
}

/// Título de seção (`##` = 2, `###` = 3). O `#` do topo vira o título da
/// tela e não entra.
class LegalHeading extends LegalBlock {
  const LegalHeading(this.level, this.spans);

  final int level;
  final List<LegalSpan> spans;

  @override
  String get plain => spans.map((s) => s.text).join();
}

class LegalParagraph extends LegalBlock {
  const LegalParagraph(this.spans);

  final List<LegalSpan> spans;

  @override
  String get plain => spans.map((s) => s.text).join();
}

/// Item de lista: com marcador ou numerado ([number]), em [depth] níveis
/// (0 = primeiro).
class LegalListItem extends LegalBlock {
  const LegalListItem(this.spans, {this.number, this.depth = 0});

  final List<LegalSpan> spans;
  final int? number;
  final int depth;

  @override
  String get plain => spans.map((s) => s.text).join();
}

/// Tabela: no celular, cada linha vira um bloco com "coluna: valor".
class LegalTable extends LegalBlock {
  const LegalTable(this.headers, this.rows);

  final List<List<LegalSpan>> headers;
  final List<List<List<LegalSpan>>> rows;

  @override
  String get plain => [
    for (final row in rows)
      [
        for (var i = 0; i < row.length; i++)
          '${i < headers.length ? headers[i].map((s) => s.text).join() : ''}: '
              '${row[i].map((s) => s.text).join()}',
      ].join('; '),
  ].join('\n');
}

/// Citação (`>`) que é para o leitor: aparece como nota em destaque.
class LegalNote extends LegalBlock {
  const LegalNote(this.spans);

  final List<LegalSpan> spans;

  @override
  String get plain => spans.map((s) => s.text).join();
}

/// Lê o Markdown dos Termos e da Política (o subconjunto que os textos
/// usam: títulos, parágrafos, listas, tabelas, negrito, código e citações).
///
/// Tira o que é interno e não vai para o app: o título `#` (já está no
/// topo da tela), as citações de rascunho ("RASCUNHO", "Nota interna") e
/// os comentários HTML. Código (`assim`) vira texto comum; links viram só o
/// texto deles.
List<LegalBlock> parseLegalMarkdown(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final blocks = <LegalBlock>[];
  final paragraph = <String>[];
  var inComment = false;

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(LegalParagraph(parseInline(paragraph.join(' '))));
    paragraph.clear();
  }

  var i = 0;
  while (i < lines.length) {
    final raw = lines[i];
    final line = raw.trimRight();
    final trimmed = line.trimLeft();

    // Comentários HTML (notas para quem edita).
    if (inComment || trimmed.startsWith('<!--')) {
      inComment = !trimmed.contains('-->');
      i++;
      continue;
    }

    if (trimmed.isEmpty) {
      flushParagraph();
      i++;
      continue;
    }

    // Títulos.
    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
    if (heading != null) {
      flushParagraph();
      final level = heading.group(1)!.length;
      if (level > 1) {
        blocks.add(
          LegalHeading(level.clamp(2, 3), parseInline(heading.group(2)!)),
        );
      }
      i++;
      continue;
    }

    // Citações: junta as linhas seguidas; as internas saem.
    if (trimmed.startsWith('>')) {
      flushParagraph();
      final quote = <String>[];
      while (i < lines.length && lines[i].trimLeft().startsWith('>')) {
        quote.add(lines[i].trimLeft().replaceFirst(RegExp(r'^>\s?'), ''));
        i++;
      }
      final text = quote.join(' ').trim();
      if (!_isInternalNote(text) && text.isNotEmpty) {
        blocks.add(LegalNote(parseInline(text)));
      }
      continue;
    }

    // Tabelas: cabeçalho, linha de separação e linhas.
    if (trimmed.startsWith('|')) {
      flushParagraph();
      final rows = <List<String>>[];
      while (i < lines.length && lines[i].trimLeft().startsWith('|')) {
        final cells = _cells(lines[i]);
        final separator = cells.every(
          (c) => RegExp(r'^:?-{2,}:?$').hasMatch(c.trim()),
        );
        if (!separator) rows.add(cells);
        i++;
      }
      if (rows.isNotEmpty) {
        blocks.add(
          LegalTable(
            [for (final h in rows.first) parseInline(h)],
            [
              for (final row in rows.skip(1))
                [for (final cell in row) parseInline(cell)],
            ],
          ),
        );
      }
      continue;
    }

    // Listas (com marcador ou numeradas); a indentação dá o nível.
    final item = RegExp(r'^(\s*)([-*+]|(\d+)[.)])\s+(.*)$').firstMatch(line);
    if (item != null) {
      flushParagraph();
      final indent = item.group(1)!.replaceAll('\t', '    ').length;
      final buffer = StringBuffer(item.group(4)!);
      i++;
      // Linhas de continuação do mesmo item (indentadas, sem marcador).
      while (i < lines.length) {
        final next = lines[i];
        if (next.trim().isEmpty ||
            !next.startsWith(' ') ||
            RegExp(r'^\s*([-*+]|\d+[.)])\s+').hasMatch(next) ||
            next.trimLeft().startsWith('|') ||
            next.trimLeft().startsWith('>')) {
          break;
        }
        buffer.write(' ${next.trim()}');
        i++;
      }
      final number = item.group(3);
      blocks.add(
        LegalListItem(
          parseInline(buffer.toString()),
          number: number == null ? null : int.parse(number),
          depth: (indent ~/ 2).clamp(0, 3),
        ),
      );
      continue;
    }

    paragraph.add(trimmed);
    i++;
  }
  flushParagraph();
  return blocks;
}

bool _isInternalNote(String text) {
  final lower = text.toLowerCase();
  return lower.contains('rascunho') || lower.contains('nota interna');
}

List<String> _cells(String line) {
  var t = line.trim();
  if (t.startsWith('|')) t = t.substring(1);
  if (t.endsWith('|')) t = t.substring(0, t.length - 1);
  return [for (final c in t.split('|')) c.trim()];
}

/// Trechos de uma linha: `**negrito**`; `código` e links viram texto.
List<LegalSpan> parseInline(String text) {
  var t = text
      // Comentário no meio da linha (nota para quem edita): sai.
      .replaceAll(RegExp(r'<!--.*?-->'), '')
      // Links: [texto](url) → texto; colchetes sem "(url)", como [FORO],
      // ficam como texto comum.
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1)!)
      // Código: `x` → x.
      .replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m.group(1)!)
      // Quebra de linha forçada.
      .replaceAll('<br>', ' ');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  final spans = <LegalSpan>[];
  final bold = RegExp(r'\*\*(.+?)\*\*');
  var last = 0;
  for (final m in bold.allMatches(t)) {
    if (m.start > last) {
      spans.add(LegalSpan(_italics(t.substring(last, m.start))));
    }
    spans.add(LegalSpan(_italics(m.group(1)!), bold: true));
    last = m.end;
  }
  if (last < t.length) spans.add(LegalSpan(_italics(t.substring(last))));
  return spans.where((s) => s.text.isNotEmpty).toList(growable: false);
}

/// Itálico (`*x*` ou `_x_`) fica como texto comum.
String _italics(String s) => s.replaceAllMapped(
  RegExp(r'(?<![\w*])[*_]([^*_]+)[*_](?![\w*])'),
  (m) => m.group(1)!,
);
