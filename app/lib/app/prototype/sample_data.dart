import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/clock.dart';
import '../../core/domain/local_date.dart';
import '../../features/focus/domain/focus_session.dart';
import '../../features/focus/domain/session_split.dart';
import '../../features/goals/application/goals_providers.dart';
import '../../features/notifications/application/notifications_providers.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../../features/notifications/domain/nexo_notification.dart';
import '../../features/plans/application/plans_providers.dart';
import '../../features/plans/domain/plan.dart';
import '../../features/plans/domain/plan_schedule.dart';
import '../../features/subjects/application/subjects_providers.dart';
import '../../features/tasks/application/tasks_providers.dart';
import '../../features/tasks/domain/task.dart';
import '../../features/tasks/domain/task_rules.dart';

/// Preenche os repositórios fake com dados de exemplo, relativos a hoje.
/// Só na prototipação (chamado pelo `main`). Instituições e nomes são
/// **fictícios**.
final prototypeSampleDataProvider = FutureProvider<void>((ref) async {
  final now = ref.read(clockProvider)();
  final today = LocalDate.fromDateTime(now);

  DateTime at(LocalDate day, int hour, [int minute = 0]) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  // Disciplinas. A cor é o nome da paleta fixa, ainda não definida pelo
  // design: `primary` até lá.
  final subjects = ref.read(subjectsRepositoryProvider);
  final calculo = await subjects.createSubject(
    name: 'Cálculo II',
    icon: 'sigma',
    color: 'primary',
  );
  final bancoDeDados = await subjects.createSubject(
    name: 'Banco de Dados',
    icon: 'database',
    color: 'primary',
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
      reminder: PlanReminder(enabled: true, time: '19:00'),
    ),
    topicNames: ['Porcentagem', 'Juros simples'],
  );
  await plans.createPlan(
    Plan(
      id: '',
      name: 'Inglês para intercâmbio',
      startDate: today.addDays(-5),
      endDate: today.addDays(60),
      frequency: WeekdaysFrequency({1, 3, 5}),
      dailyGoalMinutes: 45,
    ),
    topicNames: ['Listening', 'Vocabulário'],
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
      reminderMinutesBefore: TaskReminder.oneDay,
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
      reminderMinutesBefore: TaskReminder.oneDay,
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

  // Avisos do painel de notificações (ligados aos exemplos acima).
  final notifications = ref.read(notificationsRepositoryProvider);
  if (notifications is FakeNotificationsRepository) {
    notifications
      ..add(
        kind: NotificationKind.dueSoon,
        title: 'Entrega amanhã',
        body: 'Lista de exercícios 3 · Cálculo II · amanhã, 18:00',
        createdAt: now.subtract(const Duration(hours: 2)),
      )
      ..add(
        kind: NotificationKind.overdue,
        title: 'Tarefa atrasada',
        body: 'Resumo do capítulo 2 · venceu ontem, 23:59',
        createdAt: now.subtract(const Duration(hours: 5)),
      )
      ..add(
        kind: NotificationKind.dailyGoal,
        title: 'Meta do dia',
        body: 'Concurso Banco Horizonte · faltam 30 min para a meta de hoje',
        createdAt: now.subtract(const Duration(days: 1)),
        read: true,
      )
      ..add(
        kind: NotificationKind.achievement,
        title: 'Conquista: Primeiro foco',
        body: 'Você encerrou sua primeira sessão de foco.',
        createdAt: now.subtract(const Duration(days: 3)),
        read: true,
      );
  }
});
