import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/local_flags.dart';
import '../../../core/domain/local_date.dart';
import '../../auth/application/auth_providers.dart';
import '../../plans/application/plan_today.dart';
import '../../plans/application/plans_providers.dart';
import '../../plans/domain/plan.dart';
import '../../subjects/application/subject_actions.dart';
import '../../tasks/application/screen_now.dart';
import '../../tasks/application/task_actions.dart';
import '../../tasks/domain/task.dart';

/// O plano principal hoje (cartão `Nexo/PlanCard`). O mesmo cartão da
/// Visão geral do plano.
typedef HomePlanToday = PlanToday;

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

final homeViewProvider = Provider<HomeView?>((ref) {
  final profile = ref.watch(userProfileProvider);
  final plans = ref.watch(plansProvider);
  // Sem as de exclusão pendente (somem na hora em todas as telas).
  final tasks = ref.watch(visibleTasksProvider);
  final subjects = ref.watch(visibleSubjectsProvider);
  if (!profile.hasValue || !plans.hasValue || !tasks.hasValue) return null;

  final now = ref.watch(screenNowProvider);
  final today = LocalDate.fromDateTime(now);
  final planList = plans.value!;

  // Plano principal, em qualquer situação (pausado, arquivado, encerrado:
  // o cartão mostra o estado; nada é promovido sozinho). Sem principal
  // gravado (dado antigo) ou se ele não existe mais, o primeiro ativo.
  final primaryId = profile.value?.primaryPlanId;
  final primary =
      planList.where((p) => p.id == primaryId).firstOrNull ??
      planList.where((p) => p.status == PlanStatus.active).firstOrNull;

  HomePlanToday? planToday;
  var hasSession = false;
  if (primary != null) {
    final snapshot = ref.watch(planSnapshotProvider(primary.id));
    final streak = ref.watch(planStreakProvider(primary.id));
    if (snapshot == null || streak == null) return null;
    hasSession = snapshot.days.values.any((d) => d.doneMinutes > 0);
    planToday = planTodayOf(
      snapshot,
      today: today,
      streak: streak,
      otherActivePlans: planList.any(
        (p) => p.id != primary.id && p.status == PlanStatus.active,
      ),
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
