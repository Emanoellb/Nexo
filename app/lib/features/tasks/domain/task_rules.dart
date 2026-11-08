/// Situação da entrega da tarefa (decisão de 25/10/2026), com o valor
/// gravado no Firestore (`deliveryStatus`).
enum DeliveryStatus {
  notStarted('notStarted', 'Não iniciada'),
  inProgress('inProgress', 'Em andamento'),
  delivered('delivered', 'Entregue'),
  awaitingGrade('awaitingGrade', 'Aguardando correção');

  const DeliveryStatus(this.value, this.label);

  /// Valor persistido.
  final String value;

  /// Texto da interface.
  final String label;

  /// `null` sem valor ou com um valor desconhecido (achado [15]).
  static DeliveryStatus? fromValue(String? value) =>
      DeliveryStatus.values.where((s) => s.value == value).firstOrNull;

  /// Situações possíveis de uma tarefa pendente.
  bool get isPending => this == notStarted || this == inProgress;
}

/// Coerência exigida pelas regras: tarefa pendente só "Não iniciada" ou "Em
/// andamento"; concluída só "Entregue" ou "Aguardando correção". Sem
/// situação (`null`) é sempre válido.
bool isDeliveryStatusCoherent({
  required bool completed,
  required DeliveryStatus? status,
}) {
  if (status == null) return true;
  return completed ? !status.isPending : status.isPending;
}

/// Ao concluir: uma situação pendente vira "Entregue", no mesmo gravar.
DeliveryStatus? deliveryStatusOnComplete(DeliveryStatus? current) {
  if (current == null) return null;
  return current.isPending ? DeliveryStatus.delivered : current;
}

/// Ao reabrir (Desfazer): uma situação de concluída volta para "Em andamento".
DeliveryStatus? deliveryStatusOnReopen(DeliveryStatus? current) {
  if (current == null) return null;
  return current.isPending ? current : DeliveryStatus.inProgress;
}

/// "Atrasada": pendente e com o prazo já passado. Calculado, não gravado.
bool isTaskOverdue({
  required bool completed,
  required DateTime? dueAt,
  required DateTime now,
}) => !completed && dueAt != null && now.isAfter(dueAt);

/// "Adiar para amanhã" (deslizar à esquerda): amanhã, no mesmo horário do
/// prazo (design de 04/11/2026). "Amanhã" é a partir de hoje, não do prazo
/// antigo.
DateTime postponedDue(DateTime due, {required DateTime now}) =>
    DateTime(now.year, now.month, now.day + 1, due.hour, due.minute);

/// Adiar só existe para tarefa pendente com prazo até hoje (atrasada ou de
/// hoje): para as de amanhã em diante, "para amanhã" manteria ou adiantaria
/// o prazo (achado do code review, 05/11/2026).
bool canPostponeTask({
  required bool completed,
  required DateTime? dueAt,
  required DateTime now,
}) {
  if (completed || dueAt == null) return false;
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return dueAt.isBefore(tomorrow);
}

/// Pontos da tarefa em `users.points`: +1 ao concluir, −1 ao reabrir.
int taskPointsDelta({required bool wasCompleted, required bool isCompleted}) {
  if (wasCompleted == isCompleted) return 0;
  return isCompleted ? 1 : -1;
}

/// Avisos de entrega próxima (`remindersMinutesBefore`, v0.9): até 3 por
/// tarefa, cada um de 1 a 43.200 minutos antes do prazo, sem repetidos e só
/// com prazo. Lista vazia = sem aviso.
abstract final class TaskReminder {
  static const oneHour = 60;
  static const oneDay = 1440;
  static const oneWeek = 10080;

  /// Sugerido ao escolher um prazo ("1 dia antes").
  static const suggested = [oneDay];

  /// Limite das regras: até 30 dias.
  static const maxMinutes = 43200;

  /// Até 3 avisos por tarefa.
  static const maxCount = 3;

  /// Um valor dentro de 1–43.200.
  static bool isValidValue(int minutes) =>
      minutes >= 1 && minutes <= maxMinutes;

  /// Lista válida: vazia, ou com prazo, até [maxCount] itens válidos e
  /// sem repetidos.
  static bool isValid({
    required List<int> minutesBefore,
    required DateTime? dueAt,
  }) {
    if (minutesBefore.isEmpty) return true;
    return dueAt != null &&
        minutesBefore.length <= maxCount &&
        minutesBefore.toSet().length == minutesBefore.length &&
        minutesBefore.every(isValidValue);
  }
}
