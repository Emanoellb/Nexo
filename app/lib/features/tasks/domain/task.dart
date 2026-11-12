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

/// Ordem de `TasksRepository.watchTasks`: pendentes primeiro, por prazo
/// (sem prazo no fim, por título); depois as concluídas.
int compareTasksByDue(NexoTask a, NexoTask b) {
  if (a.completed != b.completed) return a.completed ? 1 : -1;
  final da = a.dueAt;
  final db = b.dueAt;
  if (da == null && db == null) return a.title.compareTo(b.title);
  if (da == null) return 1;
  if (db == null) return -1;
  return da.compareTo(db);
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
    List<int> remindersMinutesBefore = const [],
    this.deliveryStatus,
  }) : title = checkText(title, 'title', 1, 200),
       remindersMinutesBefore = List.unmodifiable(remindersMinutesBefore) {
    checkTextOrNull(subjectId, 'subjectId', 1, 128);
    if (!TaskReminder.isValid(
      minutesBefore: this.remindersMinutesBefore,
      dueAt: dueAt,
    )) {
      throw ArgumentError(
        'Avisos de entrega: só com prazo, até 3, sem repetidos e até 30 dias '
        'antes.',
      );
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

  /// Avisos antes do prazo, em minutos (v0.9). Vazia = sem aviso.
  final List<int> remindersMinutesBefore;
  final DeliveryStatus? deliveryStatus;

  bool isOverdue(DateTime now) =>
      isTaskOverdue(completed: completed, dueAt: dueAt, now: now);

  /// Dá para "Adiar para amanhã" (ver [canPostponeTask]).
  bool canPostpone({required DateTime now}) =>
      canPostponeTask(completed: completed, dueAt: dueAt, now: now);

  /// Cópia com campos trocados. Os anuláveis vêm como funções para poder
  /// limpar (`() => null`). Tirar o prazo esvazia os avisos no mesmo gravar
  /// (as regras negam aviso sem prazo).
  NexoTask copyWith({
    String? title,
    TaskPriority? priority,
    DateTime? Function()? dueAt,
    String? Function()? subjectId,
    List<int>? remindersMinutesBefore,
    DeliveryStatus? Function()? deliveryStatus,
  }) {
    final due = dueAt == null ? this.dueAt : dueAt();
    return NexoTask(
      id: id,
      title: title ?? this.title,
      priority: priority ?? this.priority,
      completed: completed,
      completedAt: completedAt,
      subjectId: subjectId == null ? this.subjectId : subjectId(),
      dueAt: due,
      remindersMinutesBefore: due == null
          ? const []
          : remindersMinutesBefore ?? this.remindersMinutesBefore,
      deliveryStatus: deliveryStatus == null
          ? this.deliveryStatus
          : deliveryStatus(),
    );
  }

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
      remindersMinutesBefore: remindersMinutesBefore,
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
    'remindersMinutesBefore': remindersMinutesBefore,
    'deliveryStatus': deliveryStatus?.value,
  };
}
