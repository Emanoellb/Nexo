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

/// Pontos da tarefa em `users.points`: +1 ao concluir, −1 ao reabrir.
int taskPointsDelta({required bool wasCompleted, required bool isCompleted}) {
  if (wasCompleted == isCompleted) return 0;
  return isCompleted ? 1 : -1;
}

/// Aviso de entrega próxima (`reminderMinutesBefore`): opções da tela.
abstract final class TaskReminder {
  static const oneHour = 60;
  static const oneDay = 1440;
  static const oneWeek = 10080;

  /// Limite das regras: até 30 dias.
  static const maxMinutes = 43200;

  /// Válido só com prazo e dentro de 1–43.200 minutos.
  static bool isValid({required int? minutesBefore, required DateTime? dueAt}) {
    if (minutesBefore == null) return true;
    return dueAt != null && minutesBefore >= 1 && minutesBefore <= maxMinutes;
  }
}
