import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/local_date.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_user.dart';
import '../../plans/application/plan_today.dart';
import '../../plans/application/plans_providers.dart';
import '../../plans/domain/plan.dart';
import '../../plans/domain/plan_day_result.dart';
import '../../tasks/application/screen_now.dart';
import '../../tasks/application/task_actions.dart';
import '../../tasks/domain/task.dart';

/// Um plano com meta no dia (bloco "Planos" da Agenda).
class AgendaPlan {
  const AgendaPlan({required this.plan, required this.result});

  final Plan plan;
  final PlanDayResult result;
}

/// O que a Agenda mostra de um dia (especificação de 07/11/2026).
class AgendaDay {
  const AgendaDay({
    required this.day,
    required this.plans,
    required this.tasks,
    required this.pending,
    required this.threshold,
    required this.restPlans,
  });

  final LocalDate day;

  /// Planos ativos com meta no dia, pelo horário.
  final List<AgendaPlan> plans;

  /// Tarefas com prazo no dia: pendentes pelo prazo e, depois, as
  /// concluídas (como no Início).
  final List<NexoTask> tasks;

  /// Tarefas pendentes do dia: a carga (os pontos e a sobrecarga).
  final int pending;

  /// `users.overloadThreshold` (padrão 5).
  final int threshold;

  /// Planos em que o dia é folga ("Folga do plano X").
  final List<Plan> restPlans;

  /// Passou do limite de tarefas do Perfil.
  bool get overloaded => pending > threshold;

  /// 0 a 3 pontos de carga (3 = 3 ou mais).
  int get loadDots => pending.clamp(0, 3);

  bool get isEmpty => plans.isEmpty && tasks.isEmpty;
}

/// Tarefas pendentes por dia de prazo (a carga de cada dia).
Map<LocalDate, int> pendingByDay(List<NexoTask> tasks) {
  final load = <LocalDate, int>{};
  for (final t in tasks) {
    final due = t.dueAt;
    if (due == null || t.completed) continue;
    final day = LocalDate.fromDateTime(due);
    load[day] = (load[day] ?? 0) + 1;
  }
  return load;
}

/// O próximo dia depois de [from] (e não antes de [today]) com a carga
/// abaixo do limite: a sugestão do "Mover para". Procura até 60 dias.
LocalDate suggestedMoveDay(
  Map<LocalDate, int> load,
  LocalDate from, {
  required LocalDate today,
  required int threshold,
}) {
  var day = from.addDays(1);
  if (day.isBefore(today)) day = today;
  for (var i = 0; i < 60; i++) {
    if ((load[day] ?? 0) < threshold) return day;
    day = day.addDays(1);
  }
  return from.addDays(1);
}

/// Carga de cada dia (tarefas pendentes, sem as de exclusão pendente).
final agendaLoadProvider = Provider<Map<LocalDate, int>?>((ref) {
  final tasks = ref.watch(visibleTasksProvider);
  if (!tasks.hasValue) return null;
  return pendingByDay(tasks.value!);
});

/// O limite de tarefas por dia da conta.
final overloadThresholdProvider = Provider<int>(
  (ref) =>
      ref.watch(userProfileProvider).value?.overloadThreshold ??
      UserProfile.defaultOverloadThreshold,
);

/// O dia [day] na Agenda. `null` enquanto carrega.
final agendaDayProvider = Provider.family<AgendaDay?, LocalDate>((ref, day) {
  final tasks = ref.watch(visibleTasksProvider);
  final plans = ref.watch(plansProvider);
  if (!tasks.hasValue || !plans.hasValue) return null;
  final today = LocalDate.fromDateTime(ref.watch(screenNowProvider));

  final withMeta = <AgendaPlan>[];
  final rest = <Plan>[];
  for (final plan in plans.value!) {
    if (plan.status != PlanStatus.active) continue;
    final snapshot = ref.watch(planSnapshotProvider(plan.id));
    if (snapshot == null) return null;
    final result = planDayResult(snapshot, day, today: today);
    if (result.status != PlanDayStatus.off && result.goalMinutes > 0) {
      withMeta.add(AgendaPlan(plan: plan, result: result));
    } else if (result.restDay) {
      rest.add(plan);
    }
  }
  withMeta.sort((a, b) => a.plan.studyTime.compareTo(b.plan.studyTime));

  final pending = <NexoTask>[];
  final done = <NexoTask>[];
  for (final t in tasks.value!) {
    final due = t.dueAt;
    if (due == null || LocalDate.fromDateTime(due) != day) continue;
    (t.completed ? done : pending).add(t);
  }
  int byDue(NexoTask a, NexoTask b) => a.dueAt!.compareTo(b.dueAt!);
  pending.sort(byDue);
  done.sort(byDue);

  return AgendaDay(
    day: day,
    plans: withMeta,
    tasks: [...pending, ...done],
    pending: pending.length,
    threshold: ref.watch(overloadThresholdProvider),
    restPlans: rest,
  );
});
