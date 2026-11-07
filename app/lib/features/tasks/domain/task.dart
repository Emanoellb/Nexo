import 'package:flutter/foundation.dart';

import '../../../core/domain/field_rules.dart';
import 'task_rules.dart';

/// Prioridade da tarefa (Nexo/Priority), com o valor gravado.
enum TaskPriority {
  high('Alta'),
  medium('Média'),
  low('Baixa'),
  none('Sem prioridade');

  const TaskPriority(this.label);

  final String label;

  String get value => name;

  static TaskPriority fromValue(String value) =>
      TaskPriority.values.firstWhere((p) => p.value == value);
}

/// `users/{uid}/tasks/{taskId}` (contrato §4). "Notas" ficam fora do MVP.
@immutable
class NexoTask {
  NexoTask({
    required this.id,
    required String title,
    this.priority = TaskPriority.none,
    this.completed = false,
    this.completedAt,
    this.subjectId,
    this.dueAt,
    this.reminderMinutesBefore,
    this.deliveryStatus,
  }) : title = checkText(title, 'title', 1, 200) {
    checkTextOrNull(subjectId, 'subjectId', 1, 128);
    if (!TaskReminder.isValid(
      minutesBefore: reminderMinutesBefore,
      dueAt: dueAt,
    )) {
      throw ArgumentError('Aviso de entrega só com prazo e até 30 dias antes.');
    }
    if (!isDeliveryStatusCoherent(
      completed: completed,
      status: deliveryStatus,
    )) {
      throw ArgumentError('Situação da entrega incoerente com a conclusão.');
    }
  }

  final String id;
  final String title;
  final TaskPriority priority;
  final bool completed;

  /// Carimbo do servidor ao concluir; `null` se pendente.
  final DateTime? completedAt;
  final String? subjectId;

  /// `null` = "Sem prazo".
  final DateTime? dueAt;
  final int? reminderMinutesBefore;
  final DeliveryStatus? deliveryStatus;

  bool isOverdue(DateTime now) =>
      isTaskOverdue(completed: completed, dueAt: dueAt, now: now);

  /// Dá para "Adiar para amanhã" (ver [canPostponeTask]).
  bool canPostpone({required DateTime now}) =>
      canPostponeTask(completed: completed, dueAt: dueAt, now: now);

  /// Cópia com outro prazo ou outra disciplina. Os parâmetros são funções
  /// para poder limpar (`() => null`).
  NexoTask copyWith({
    DateTime? Function()? dueAt,
    String? Function()? subjectId,
  }) => NexoTask(
    id: id,
    title: title,
    priority: priority,
    completed: completed,
    completedAt: completedAt,
    subjectId: subjectId == null ? this.subjectId : subjectId(),
    dueAt: dueAt == null ? this.dueAt : dueAt(),
    reminderMinutesBefore: reminderMinutesBefore,
    deliveryStatus: deliveryStatus,
  );

  /// Concluir ou reabrir, já com a situação da entrega coerente (mesmo
  /// gravar). O `completedAt` real é o carimbo do servidor; aqui, [now].
  NexoTask withCompleted(bool value, {required DateTime now}) {
    if (value == completed) return this;
    return NexoTask(
      id: id,
      title: title,
      priority: priority,
      completed: value,
      completedAt: value ? now : null,
      subjectId: subjectId,
      dueAt: dueAt,
      reminderMinutesBefore: reminderMinutesBefore,
      deliveryStatus: value
          ? deliveryStatusOnComplete(deliveryStatus)
          : deliveryStatusOnReopen(deliveryStatus),
    );
  }

  Map<String, Object?> toMap() => {
    'title': title,
    'priority': priority.value,
    'completed': completed,
    'completedAt': completedAt,
    'subjectId': subjectId,
    'dueAt': dueAt,
    'reminderMinutesBefore': reminderMinutesBefore,
    'deliveryStatus': deliveryStatus?.value,
  };
}
