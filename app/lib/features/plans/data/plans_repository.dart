import '../../../core/domain/local_date.dart';
import '../../focus/domain/focus_session.dart';
import '../../focus/domain/session_split.dart';
import '../domain/plan.dart';
import '../domain/plan_schedule.dart';

/// Tópico a criar junto com o plano (passo 3 do Criar plano).
typedef NewTopic = ({String name, String? subjectId});

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
  Future<Plan> createPlan(Plan draft, {List<NewTopic> topics = const []});

  Future<void> updatePlan(Plan plan);

  /// Nova meta ou frequência, valendo a partir de [effectiveFrom] (RF04).
  /// Atualiza a cópia em `plans` no mesmo lote.
  Future<void> addScheduleVersion(String planId, ScheduleVersion version);

  Future<PlanTopic> addTopic(String planId, String name, {String? subjectId});

  /// Nome e disciplina do tópico.
  Future<void> updateTopic(String planId, PlanTopic topic);
  Future<void> deleteTopic(String planId, String topicId);

  /// "Excluir plano" (sem volta): marca `status: "deleting"`, apaga
  /// sessões, dias, tópicos e versões e, por último, o plano. Quem chama
  /// limpa o `primaryPlanId` antes, se for o principal.
  Future<void> deletePlan(String planId);

  /// Grava as partes de uma sessão (já divididas à meia-noite) e atualiza o
  /// `doneMinutes` de cada dia, no mesmo lote. Recusa dias fora da janela de
  /// 7 dias.
  Future<List<FocusSession>> addSessions(
    String planId,
    List<DaySegment> segments, {
    required SessionSource source,
    List<String> topicIds = const [],
    String? note,
  });

  /// Troca uma sessão (dia, horário, tópicos, nota) e refaz o
  /// `doneMinutes` dos dias de antes e de depois, no mesmo lote. Os dois
  /// dias precisam estar na janela de 7 dias.
  Future<void> updateSession(String planId, FocusSession session);

  /// Apaga a sessão e desconta do dia (dentro da janela de 7 dias).
  Future<void> deleteSession(String planId, String sessionId);

  /// Finalizar o dia (RF14): grava `finalizedAt` (hora do servidor).
  Future<void> finalizeDay(String planId, LocalDate day);

  /// "Desfazer" (RF17): grava `finalizedAt: null` e mantém o documento do
  /// dia. Nunca `FieldValue.delete()`: as regras v0.8 exigem o campo.
  Future<void> undoFinalizeDay(String planId, LocalDate day);
}
