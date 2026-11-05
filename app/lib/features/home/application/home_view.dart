import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../../../core/data/local_flags.dart';
import '../../../core/domain/local_date.dart';
import '../../auth/application/auth_providers.dart';
import '../../plans/application/plans_providers.dart';
import '../../plans/domain/plan.dart';
import '../../plans/domain/plan_day_result.dart';
import '../../subjects/application/subjects_providers.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../tasks/domain/task.dart';

/// O plano principal hoje (cartão `Nexo/PlanCard`).
@immutable
class HomePlanToday {
  const HomePlanToday({
    required this.plan,
    required this.today,
    required this.dayNumber,
    required this.totalDays,
    required this.streak,
  });

  final Plan plan;
  final PlanDayResult today;

  /// "Dia X de N"; `dayNumber` fora de 1..N quando hoje está fora do
  /// período.
  final int dayNumber;
  final int totalDays;
  final int streak;
}

/// "Primeiros passos" (estados 02–05): criar tarefa, criar plano, focar.
@immutable
class HomeFirstSteps {
  const HomeFirstSteps({
    required this.task,
    required this.plan,
    required this.session,
  });

  final bool task;
  final bool plan;
  final bool session;

  int get done => [task, plan, session].where((d) => d).length;
  bool get complete => done == 3;
}

/// Um bloco de tarefas (Hoje ou Próximas entregas): todas do grupo, na
/// ordem (pendentes primeiro); a tela mostra até 3 (Miller).
@immutable
class HomeTaskGroup {
  const HomeTaskGroup(this.tasks);

  final List<NexoTask> tasks;

  int get completed => tasks.where((t) => t.completed).length;
  bool get isEmpty => tasks.isEmpty;
}

/// O próximo instante em que o Início precisa se recalcular: a meia-noite
/// ou o prazo pendente mais próximo, o que vier antes.
DateTime nextHomeRefresh(DateTime now, Iterable<NexoTask> tasks) {
  var next = DateTime(now.year, now.month, now.day + 1);
  for (final task in tasks) {
    final due = task.dueAt;
    if (task.completed || due == null || !due.isAfter(now)) continue;
    if (due.isBefore(next)) next = due;
  }
  return next;
}

/// Tudo o que o Início mostra, já decidido. `null` em [homeViewProvider]
/// enquanto os dados carregam (estado 01).
@immutable
class HomeView {
  const HomeView({
    required this.plan,
    required this.firstSteps,
    required this.showFirstSteps,
    required this.today,
    required this.upcoming,
    required this.subjects,
  });

  final HomePlanToday? plan;
  final HomeFirstSteps firstSteps;

  /// O cartão (ou a linha) de "Primeiros passos" aparece.
  final bool showFirstSteps;
  final HomeTaskGroup today;
  final HomeTaskGroup upcoming;

  /// Nome da disciplina por id.
  final Map<String, String> subjects;
}

/// Marca "Primeiros passos concluídos ou dispensados" da conta atual.
final firstStepsDoneProvider = NotifierProvider<FirstStepsDone, bool>(
  FirstStepsDone.new,
);

class FirstStepsDone extends Notifier<bool> {
  @override
  bool build() {
    final uid = ref.watch(currentUidProvider);
    return uid != null && ref.read(localFlagsProvider).firstStepsDone(uid);
  }

  Future<void> markDone() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || state) return;
    state = true;
    await ref.read(localFlagsProvider).markFirstStepsDone(uid);
  }
}

/// Grupos de tarefas do Início:
/// - Hoje: pendentes com prazo até hoje (atrasadas incluídas) e as que
///   vencem hoje já concluídas;
/// - Próximas entregas: pendentes com prazo nos próximos 7 dias.
({HomeTaskGroup today, HomeTaskGroup upcoming}) groupTasks(
  List<NexoTask> tasks,
  DateTime now,
) {
  final today = LocalDate.fromDateTime(now);
  final pendingToday = <NexoTask>[];
  final doneToday = <NexoTask>[];
  final upcoming = <NexoTask>[];
  // A ordem do repositório (pendentes por prazo) é mantida.
  for (final task in tasks) {
    final due = task.dueAt;
    if (due == null) continue;
    final days = today.daysUntil(LocalDate.fromDateTime(due));
    if (task.completed) {
      if (days == 0) doneToday.add(task);
    } else if (days <= 0) {
      pendingToday.add(task);
    } else if (days <= 7) {
      upcoming.add(task);
    }
  }
  return (
    today: HomeTaskGroup([...pendingToday, ...doneToday]),
    upcoming: HomeTaskGroup(upcoming),
  );
}

/// "Agora" do Início. Lido uma vez e renovado pela tela (timer) à meia-noite
/// e na hora do próximo prazo: sem isso, o cartão ficaria no dia anterior e
/// prazos vencidos não virariam "Atrasada" até algum dado mudar.
final homeNowProvider = Provider<DateTime>((ref) => ref.watch(clockProvider)());

/// Sequência do plano, à parte do Início: só refaz quando o plano, as
/// versões, os dias ou o "agora" mudam (não a cada toque numa tarefa).
/// `null` enquanto carrega.
final planStreakProvider = Provider.family<int?, String>((ref, planId) {
  final plan = ref.watch(planProvider(planId)).value;
  final versions = ref.watch(planVersionsProvider(planId));
  final days = ref.watch(planDaysProvider(planId));
  if (plan == null || !versions.hasValue || !days.hasValue) return null;
  final today = LocalDate.fromDateTime(ref.watch(homeNowProvider));
  return currentStreak(
    PlanSnapshot(plan: plan, versions: versions.value!, days: days.value!),
    today: today,
  );
});

final homeViewProvider = Provider<HomeView?>((ref) {
  final profile = ref.watch(userProfileProvider);
  final plans = ref.watch(plansProvider);
  final tasks = ref.watch(tasksProvider);
  final subjects = ref.watch(subjectsProvider);
  if (!profile.hasValue || !plans.hasValue || !tasks.hasValue) return null;

  final now = ref.watch(homeNowProvider);
  final today = LocalDate.fromDateTime(now);
  final planList = plans.value!;

  // Plano principal; se ele sumiu, o primeiro ativo.
  final primaryId = profile.value?.primaryPlanId;
  final primary =
      planList.where((p) => p.id == primaryId).firstOrNull ??
      planList.where((p) => p.status == PlanStatus.active).firstOrNull;

  HomePlanToday? planToday;
  var hasSession = false;
  if (primary != null) {
    final versions = ref.watch(planVersionsProvider(primary.id));
    final days = ref.watch(planDaysProvider(primary.id));
    final streak = ref.watch(planStreakProvider(primary.id));
    if (!versions.hasValue || !days.hasValue || streak == null) return null;
    final snapshot = PlanSnapshot(
      plan: primary,
      versions: versions.value!,
      days: days.value!,
    );
    hasSession = days.value!.any((d) => d.doneMinutes > 0);
    planToday = HomePlanToday(
      plan: primary,
      today: planDayResult(snapshot, today, today: today),
      dayNumber: primary.startDate.daysUntil(today) + 1,
      totalDays: primary.startDate.daysUntil(primary.endDate) + 1,
      streak: streak,
    );
  }

  final taskList = tasks.value!;
  final steps = HomeFirstSteps(
    task: taskList.isNotEmpty,
    plan: planList.isNotEmpty,
    session: hasSession,
  );
  final groups = groupTasks(taskList, now);

  return HomeView(
    plan: planToday,
    firstSteps: steps,
    showFirstSteps: !steps.complete && !ref.watch(firstStepsDoneProvider),
    today: groups.today,
    upcoming: groups.upcoming,
    subjects: {for (final s in subjects.value ?? const []) s.id: s.name},
  );
});
