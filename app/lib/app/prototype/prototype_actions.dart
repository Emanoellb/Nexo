import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/clock.dart';
import '../../core/domain/local_date.dart';
import '../../features/progress/application/progress_actions.dart';
import '../../features/plans/domain/plan.dart';
import '../../features/plans/domain/plan_schedule.dart';
import '../../features/tasks/application/tasks_providers.dart';
import '../../features/tasks/domain/task.dart';

/// Ações simuladas da prototipação (decisão do usuário, 04/11/2026): as
/// telas de criar tarefa e plano ainda não existem, então "Nova tarefa" e
/// "Novo plano" criam um exemplo fictício nos dados fake. Saem quando as
/// telas reais entrarem.
class PrototypeActions {
  PrototypeActions(this._ref);

  final Ref _ref;
  var _tasks = 0;
  var _plans = 0;

  DateTime get _now => _ref.read(clockProvider)();

  Future<NexoTask> createSampleTask() {
    final now = _now;
    _tasks++;
    return _ref
        .read(tasksRepositoryProvider)
        .createTask(
          NexoTask(
            id: '',
            title: 'Tarefa de exemplo $_tasks',
            dueAt: DateTime(now.year, now.month, now.day, 18),
          ),
        );
  }

  /// Pelo [ProgressActions]: o primeiro plano vira o principal.
  Future<Plan> createSamplePlan() {
    final today = LocalDate.fromDateTime(_now);
    _plans++;
    return _ref
        .read(progressActionsProvider)
        .createPlan(
          Plan(
            id: '',
            name: 'Plano de exemplo $_plans',
            startDate: today,
            endDate: today.addDays(299),
            frequency: const DailyFrequency(),
            dailyGoalMinutes: 90,
          ),
          topicNames: ['Tópico 1', 'Tópico 2'],
        );
  }
}

final prototypeActionsProvider = Provider<PrototypeActions>(
  PrototypeActions.new,
);
