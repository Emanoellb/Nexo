// Dados da vitrine do README: os exemplos de test/fakes/sample_data.dart,
// ajustados só para as imagens (o test/fakes e os testes não mudam).
//
// O plano principal começa há 6 dias, todos dentro da janela de 7 dias, e
// cada dia passou da meta. Assim:
// - o saldo fica positivo;
// - a sequência atual é igual à maior;
// - os pontos saem das regras do app.
// A tarefa "Resumo do capítulo 2" vence hoje, sem atraso.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/focus/domain/focus_session.dart';
import 'package:nexo/features/focus/domain/session_split.dart';
import 'package:nexo/features/goals/application/goals_providers.dart';
import 'package:nexo/features/plans/application/plans_providers.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/plans/domain/plan_day_result.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';
import 'package:nexo/features/subjects/application/subjects_providers.dart';
import 'package:nexo/features/tasks/application/tasks_providers.dart';
import 'package:nexo/features/tasks/domain/task.dart';
import 'package:nexo/features/tasks/domain/task_rules.dart';

/// Semeia a conta logada com os dados da vitrine. Usado no lugar do
/// `prototypeSampleDataProvider` (override no gerador).
Future<void> seedReadmeData(Ref ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return;
  final now = ref.read(clockProvider)();
  final today = LocalDate.fromDateTime(now);

  DateTime at(LocalDate day, int hour, [int minute = 0]) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  // Disciplinas.
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
      startDate: today.addDays(-6),
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
  await ref
      .read(userProfileRepositoryProvider)
      .setPrimaryPlan(uid, concurso.id);
  final ingles = await plans.createPlan(
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

  Future<void> study(String planId, LocalDate day, int hour, int minutes) =>
      plans.addSessions(
        planId,
        splitSessionByDay([
          ActiveInterval(
            at(day, hour),
            at(day, hour).add(Duration(minutes: minutes)),
          ),
        ]),
        source: SessionSource.focus,
      );

  // Concurso: todos os dias acima da meta de 1h30.
  const minutesByDaysAgo = {6: 105, 5: 100, 4: 110, 3: 95, 2: 105, 1: 100};
  for (final MapEntry(key: daysAgo, value: minutes)
      in minutesByDaysAgo.entries) {
    await study(concurso.id, today.addDays(-daysAgo), 19, minutes);
  }
  // Hoje: 1h de 1h30, de manhã.
  await study(concurso.id, today, 8, 60);

  // Inglês (segunda, quarta e sexta): os dias de estudo até ontem cumpridos.
  for (var daysAgo = 5; daysAgo >= 1; daysAgo--) {
    final day = today.addDays(-daysAgo);
    if ({1, 3, 5}.contains(day.weekday)) {
      await study(ingles.id, day, 21, 50);
    }
  }

  // Tarefas.
  final tasks = ref.read(tasksRepositoryProvider);
  await tasks.createTask(
    NexoTask(
      id: '',
      title: 'Resumo do capítulo 2',
      priority: TaskPriority.medium,
      subjectId: calculo.id,
      dueAt: at(today, 23, 59),
    ),
  );
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
      title: 'Revisar juros compostos',
      priority: TaskPriority.low,
    ),
  );
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

  // users.points = dias dos planos + tarefas concluídas (regras do app).
  var points = (await tasks.watchTasks().first)
      .where((t) => t.completed)
      .length;
  for (final plan in await plans.watchPlans().first) {
    points += planTotalPoints(
      PlanSnapshot(
        plan: plan,
        versions: await plans.watchVersions(plan.id).first,
        days: await plans.watchDays(plan.id).first,
      ),
      today: today,
    );
  }
  final profiles = ref.read(userProfileRepositoryProvider);
  final current = (await profiles.watchProfile(uid).first)?.points ?? 0;
  await profiles.addPoints(uid, points - current);
}
