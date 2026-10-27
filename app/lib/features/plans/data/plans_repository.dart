import '../../../core/domain/local_date.dart';
import '../../focus/domain/focus_session.dart';
import '../../focus/domain/session_split.dart';
import '../domain/plan.dart';
import '../domain/plan_schedule.dart';

/// Planos e as subcoleções (`scheduleVersions`, `topics`, `sessions`,
/// `days`). A versão Firestore implementa esta interface no bloco de
/// integração, seguindo `firestore-rules.md` §4 e §7.
abstract interface class PlansRepository {
  Stream<List<Plan>> watchPlans();
  Stream<Plan?> watchPlan(String planId);
  Stream<List<ScheduleVersion>> watchVersions(String planId);
  Stream<List<PlanTopic>> watchTopics(String planId);
  Stream<List<PlanDay>> watchDays(String planId);
  Stream<List<FocusSession>> watchSessions(String planId);

  /// Plano + versão inicial (`effectiveFrom` = início) + tópicos, no mesmo
  /// lote. Devolve o plano com o id criado.
  Future<Plan> createPlan(Plan draft, {List<String> topicNames = const []});

  Future<void> updatePlan(Plan plan);

  /// Nova meta ou frequência, valendo a partir de [effectiveFrom] (RF04).
  /// Atualiza a cópia em `plans` no mesmo lote.
  Future<void> addScheduleVersion(String planId, ScheduleVersion version);

  Future<PlanTopic> addTopic(String planId, String name, {String? subjectId});
  Future<void> renameTopic(String planId, String topicId, String name);
  Future<void> deleteTopic(String planId, String topicId);

  /// Grava as partes de uma sessão (já divididas à meia-noite) e atualiza o
  /// `doneMinutes` de cada dia, no mesmo lote. Recusa dias fora da janela de
  /// 7 dias.
  Future<List<FocusSession>> addSessions(
    String planId,
    List<DaySegment> segments, {
    required SessionSource source,
    String? topicId,
    String? note,
  });

  /// Apaga a sessão e desconta do dia (dentro da janela de 7 dias).
  Future<void> deleteSession(String planId, String sessionId);

  /// Finalizar o dia (RF14) e o "Desfazer" (RF17).
  Future<void> finalizeDay(String planId, LocalDate day);
  Future<void> undoFinalizeDay(String planId, LocalDate day);
}
