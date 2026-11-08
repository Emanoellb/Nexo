import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/clock.dart';
import '../../core/domain/local_date.dart';
import '../../features/progress/application/progress_actions.dart';
import '../../features/plans/domain/plan.dart';
import '../../features/plans/domain/plan_schedule.dart';

/// Ações simuladas da prototipação (decisão do usuário, 04/11/2026): a
/// tela de criar plano ainda não existe, então "Novo plano" cria um exemplo
/// fictício nos dados fake. Sai quando a tela real entrar (a de tarefa
/// entrou em 07/11/2026).
class PrototypeActions {
  PrototypeActions(this._ref);

  final Ref _ref;
  var _plans = 0;

  DateTime get _now => _ref.read(clockProvider)();

  /// Pelo [ProgressActions]: o primeiro plano vira o principal;
  /// [makePrimary] força (cartão do plano encerrado, "Criar plano").
  Future<Plan> createSamplePlan({bool makePrimary = false}) {
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
          makePrimary: makePrimary,
        );
  }
}

final prototypeActionsProvider = Provider<PrototypeActions>(
  PrototypeActions.new,
);
