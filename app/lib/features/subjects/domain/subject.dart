import 'package:flutter/foundation.dart';

import '../../../core/domain/field_rules.dart';

/// `users/{uid}/subjects/{subjectId}` (contrato §4): disciplina com ícone e
/// cor escolhidos pelo usuário.
///
/// [color] é o **nome** de uma cor da paleta fixa do design, não um código
/// de cor. A paleta ainda não foi definida (pendência do design); até lá os
/// dados de exemplo usam `primary`.
@immutable
class Subject {
  Subject({
    required this.id,
    required String name,
    required String icon,
    required String color,
  }) : name = checkText(name, 'name', 1, 80),
       icon = checkText(icon, 'icon', 1, 64),
       color = checkText(color, 'color', 1, 32);

  final String id;
  final String name;

  /// Nome do ícone Lucide (ex.: `sigma`).
  final String icon;
  final String color;

  Map<String, Object?> toMap() => {'name': name, 'icon': icon, 'color': color};
}
