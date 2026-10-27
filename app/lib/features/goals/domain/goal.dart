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

  Map<String, Object?> toMap() => {
    'name': name,
    'description': description,
    'deadline': deadline?.toIso(),
  };
}
