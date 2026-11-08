import 'package:flutter/foundation.dart';

import '../../../core/domain/field_rules.dart';
import '../../../core/domain/local_date.dart';

/// `users/{uid}/goals/{goalId}` (contrato §4). Opcional: um objetivo agrupa
/// planos (`plans.goalId`). Na navegação, fica dentro de Planos.
@immutable
class Goal {
  Goal({
    required this.id,
    required String name,
    String? description,
    this.deadline,
  }) : name = checkText(name, 'name', 1, 80),
       description = checkTextOrNull(description, 'description', 0, 500);

  final String id;
  final String name;
  final String? description;
  final LocalDate? deadline;

  /// Cópia com campos trocados. Os anuláveis vêm como funções para poder
  /// limpar (`() => null`).
  Goal copyWith({
    String? name,
    String? Function()? description,
    LocalDate? Function()? deadline,
  }) => Goal(
    id: id,
    name: name ?? this.name,
    description: description == null ? this.description : description(),
    deadline: deadline == null ? this.deadline : deadline(),
  );

  Map<String, Object?> toMap() => {
    'name': name,
    'description': description,
    'deadline': deadline?.toIso(),
  };
}
