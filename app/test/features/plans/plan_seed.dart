import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/focus/domain/focus_session.dart';
import 'package:nexo/features/focus/domain/session_split.dart';
import 'package:nexo/features/plans/data/plans_repository.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';

/// Quarta, 04/11/2026, 10:00 (semana do Nexo: domingo 01 a sábado 07).
final seedNow = DateTime(2026, 11, 4, 10);
const seedToday = LocalDate(2026, 11, 4);

/// Plano "todos os dias", 1h por dia, desde domingo 25/10, com:
/// - 29/10: 60 min (na meta), tópico Porcentagem;
/// - 30/10: 75 min (com horas a mais), Porcentagem e Juros simples;
/// - 31/10: 30 min e finalizado (com horas a menos);
/// - 02/11: 60 min (na meta), Juros simples;
/// - 25 a 28/10, 01/11 e 03/11 sem nada (não cumprido).
///
/// Até ontem: 600 min planejados, 225 dedicados; 2 na meta, 1 a mais, 1 a
/// menos, 6 não cumpridos; maior sequência 3; sequência atual 0; 20 pontos.
Future<({Plan plan, String porcentagem, String juros})> seedPlanHistory(
  PlansRepository repo, {
  String name = 'Concurso Banco Horizonte',
  String? goalId,
}) async {
  final plan = await repo.createPlan(
    Plan(
      id: '',
      name: name,
      startDate: const LocalDate(2026, 10, 25),
      endDate: const LocalDate(2027, 8, 10),
      frequency: const DailyFrequency(),
      dailyGoalMinutes: 60,
      goalId: goalId,
    ),
    topics: const [
      (name: 'Porcentagem', subjectId: null),
      (name: 'Juros simples', subjectId: null),
    ],
  );
  final topics = await repo.watchTopics(plan.id).first;
  final p = topics.firstWhere((t) => t.name == 'Porcentagem').id;
  final j = topics.firstWhere((t) => t.name == 'Juros simples').id;

  Future<void> session(LocalDate day, int minutes, List<String> topicIds) {
    final start = DateTime(day.year, day.month, day.day, 19);
    return repo.addSessions(
      plan.id,
      splitSessionByDay([
        ActiveInterval(start, start.add(Duration(minutes: minutes))),
      ]),
      source: SessionSource.focus,
      topicIds: topicIds,
    );
  }

  await session(const LocalDate(2026, 10, 29), 60, [p]);
  await session(const LocalDate(2026, 10, 30), 75, [p, j]);
  await session(const LocalDate(2026, 10, 31), 30, const []);
  await repo.finalizeDay(plan.id, const LocalDate(2026, 10, 31));
  await session(const LocalDate(2026, 11, 2), 60, [j]);
  return (plan: plan, porcentagem: p, juros: j);
}
