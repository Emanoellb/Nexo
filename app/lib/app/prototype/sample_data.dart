import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/clock.dart';
import '../../core/domain/local_date.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/data/fake_auth_repository.dart';
import '../../features/focus/domain/focus_session.dart';
import '../../features/focus/domain/session_split.dart';
import '../../features/goals/application/goals_providers.dart';
import '../../features/plans/application/plans_providers.dart';
import '../../features/plans/domain/plan.dart';
import '../../features/plans/domain/plan_day_result.dart';
import '../../features/plans/domain/plan_schedule.dart';
import '../../features/subjects/application/subjects_providers.dart';
import '../../features/tasks/application/tasks_providers.dart';
import '../../features/tasks/domain/task.dart';
import '../../features/tasks/domain/task_rules.dart';

/// Liga os dados de exemplo. O `main` liga; nos testes fica desligado, para
/// cada teste montar só os dados de que precisa.
final prototypeSeedingProvider = Provider<bool>((ref) => false);

/// Preenche os repositórios fake com dados de exemplo, relativos a hoje.
/// Só na prototipação e só na conta de protótipo (Ana): os dados são por
/// conta, e uma conta nova começa vazia, para percorrer o Início do zero
/// (decisão do usuário, 05/11/2026). Instituições e nomes são **fictícios**.
///
/// Refaz a cada troca de conta (os repositórios também são recriados).
final prototypeSampleDataProvider = FutureProvider<void>((ref) async {
  const uid = FakeAuthRepository.prototypeUserUid;
  if (!ref.watch(prototypeSeedingProvider) ||
      ref.watch(currentUidProvider) != uid) {
    return;
  }
  final now = ref.read(clockProvider)();
  final today = LocalDate.fromDateTime(now);

  DateTime at(LocalDate day, int hour, [int minute = 0]) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  // Disciplinas (nome + ícone; sem cor no MVP).
  final subjects = ref.read(subjectsRepositoryProvider);
  final calculo = await subjects.createSubject(
    name: 'Cálculo II',
    icon: 'calculator',
  );
  final bancoDeDados = await subjects.createSubject(
    name: 'Banco de Dados',
    icon: 'database',
  );

  // Objetivo.
  final goal = await ref
      .read(goalsRepositoryProvider)
      .createGoal(
        name: 'Aprovação no Concurso Banco Horizonte',
        description: 'Prova prevista para o início do próximo ano.',
        deadline: today.addDays(120),
      );

  // Planos.
  final plans = ref.read(plansRepositoryProvider);
  final concurso = await plans.createPlan(
    Plan(
      id: '',
      name: 'Concurso Banco Horizonte',
      startDate: today.addDays(-20),
      endDate: today.addDays(100),
      frequency: const DailyFrequency(),
      dailyGoalMinutes: 90,
      goalId: goal.id,
    ),
    topics: [
      (name: 'Porcentagem', subjectId: null),
      (name: 'Juros simples', subjectId: null),
    ],
  );
  // O primeiro plano é o principal (o do Início).
  await ref
      .read(userProfileRepositoryProvider)
      .setPrimaryPlan(uid, concurso.id);
  await plans.createPlan(
    Plan(
      id: '',
      name: 'Inglês para intercâmbio',
      startDate: today.addDays(-5),
      endDate: today.addDays(60),
      frequency: WeekdaysFrequency({1, 3, 5}),
      dailyGoalMinutes: 45,
    ),
    topics: [
      (name: 'Listening', subjectId: null),
      (name: 'Vocabulário', subjectId: null),
    ],
  );

  // Sessões dos últimos dias (dentro da janela de 7 dias) e dias finalizados.
  const minutesByDaysAgo = {5: 30, 4: 95, 3: 45, 2: 90, 1: 60};
  for (final MapEntry(key: daysAgo, value: minutes)
      in minutesByDaysAgo.entries) {
    final day = today.addDays(-daysAgo);
    final start = at(day, 19);
    await plans.addSessions(
      concurso.id,
      splitSessionByDay([
        ActiveInterval(start, start.add(Duration(minutes: minutes))),
      ]),
      source: SessionSource.focus,
    );
    if (daysAgo >= 2) await plans.finalizeDay(concurso.id, day);
  }
  // Hoje: 60 de 90 min, se a manhã já passou.
  final todayStart = at(today, 8);
  final todayEnd = todayStart.add(const Duration(minutes: 60));
  if (now.isAfter(todayEnd)) {
    await plans.addSessions(
      concurso.id,
      splitSessionByDay([ActiveInterval(todayStart, todayEnd)]),
      source: SessionSource.focus,
    );
  }

  // Tarefas.
  final tasks = ref.read(tasksRepositoryProvider);
  await tasks.createTask(
    NexoTask(
      id: '',
      title: 'Lista de exercícios 3',
      priority: TaskPriority.high,
      subjectId: calculo.id,
      dueAt: at(today.addDays(1), 18),
      remindersMinutesBefore: TaskReminder.suggested,
      deliveryStatus: DeliveryStatus.inProgress,
    ),
  );
  await tasks.createTask(
    NexoTask(
      id: '',
      title: 'Trabalho de modelagem do banco',
      priority: TaskPriority.medium,
      subjectId: bancoDeDados.id,
      dueAt: at(today.addDays(6), 23, 59),
      remindersMinutesBefore: TaskReminder.suggested,
      deliveryStatus: DeliveryStatus.notStarted,
    ),
  );
  await tasks.createTask(
    NexoTask(
      id: '',
      title: 'Resumo do capítulo 2',
      priority: TaskPriority.medium,
      subjectId: calculo.id,
      dueAt: at(today.addDays(-1), 23, 59),
    ),
  );
  await tasks.createTask(
    NexoTask(
      id: '',
      title: 'Revisar juros compostos',
      priority: TaskPriority.low,
    ),
  );
  // Uma concluída: ao concluir, a situação "Em andamento" vira "Entregue".
  final relatorio = await tasks.createTask(
    NexoTask(
      id: '',
      title: 'Entrega do relatório parcial',
      subjectId: bancoDeDados.id,
      dueAt: at(today.addDays(-2), 18),
      deliveryStatus: DeliveryStatus.inProgress,
    ),
  );
  await tasks.setCompleted(relatorio.id, true);

  // users.points coerente com o que foi semeado (dias do plano + tarefas
  // concluídas). O perfil fake sobrevive a novos logins, então o valor é
  // ajustado ao total, não somado.
  var points = (await tasks.watchTasks().first)
      .where((t) => t.completed)
      .length;
  for (final plan in await plans.watchPlans().first) {
    final snapshot = PlanSnapshot(
      plan: plan,
      versions: await plans.watchVersions(plan.id).first,
      days: await plans.watchDays(plan.id).first,
    );
    points += planTotalPoints(snapshot, today: today);
  }
  final profiles = ref.read(userProfileRepositoryProvider);
  final current = (await profiles.watchProfile(uid).first)?.points ?? 0;
  await profiles.addPoints(uid, points - current);

  // Sem avisos de exemplo no sino (decisão do usuário, 10/11/2026): ele
  // fica no estado vazio até os avisos de verdade (Etapa 4/5).
});
