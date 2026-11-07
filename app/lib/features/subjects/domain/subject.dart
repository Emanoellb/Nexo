import 'package:flutter/foundation.dart';

import '../../../core/domain/field_rules.dart';

/// `users/{uid}/subjects/{subjectId}` (contrato §4): `{name, icon}`.
///
/// Sem cor: a cor por disciplina saiu do MVP (regras v0.8 publicadas negam
/// `color`; decisão de 04/11/2026).
@immutable
class Subject {
  Subject({required this.id, required String name, required String icon})
    : name = checkText(name, 'name', 1, maxNameLength),
      icon = checkText(icon, 'icon', 1, 64);

  /// Limite das regras para o nome.
  static const maxNameLength = 80;

  final String id;
  final String name;

  /// Nome do ícone Lucide (ex.: `book-open`), um dos de [subjectIcons].
  final String icon;

  Subject copyWith({String? name, String? icon}) =>
      Subject(id: id, name: name ?? this.name, icon: icon ?? this.icon);

  Map<String, Object?> toMap() => {'name': name, 'icon': icon};

  @override
  bool operator ==(Object other) =>
      other is Subject &&
      other.id == id &&
      other.name == name &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(id, name, icon);
}

/// Os 12 ícones do cadastro de disciplina (design de 04/11/2026), na ordem
/// da grade. O primeiro é o padrão.
const subjectIcons = [
  'book-open',
  'calculator',
  'atom',
  'code',
  'database',
  'languages',
  'scale',
  'flask-conical',
  'palette',
  'globe',
  'landmark',
  'brain',
];

/// Chave para ordenar e comparar nomes: sem acento, sem diferença de
/// maiúsculas e sem espaços nas pontas ("Álgebra" fica junto de "algebra").
String subjectNameKey(String name) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final lower = name.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    buffer.write(i >= 0 ? to[i] : ch);
  }
  return buffer.toString();
}
