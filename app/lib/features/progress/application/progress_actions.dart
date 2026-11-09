import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../../../core/domain/local_date.dart';
import '../../auth/application/auth_providers.dart';
import '../../focus/domain/focus_session.dart';
import '../../focus/domain/session_split.dart';
import '../../plans/application/plans_providers.dart';
import '../../plans/data/plans_repository.dart';
import '../../plans/domain/plan.dart';
import '../../plans/domain/plan_day_result.dart';
import '../../plans/domain/plan_schedule.dart';
import '../../tasks/application/tasks_providers.dart';

/// Ações que mexem em pontos ou no plano principal, sempre com o ajuste no
/// perfil junto (sem Cloud Function no MVP: o app mantém `users.points` e
/// `users.primaryPlanId`; decisão do usuário, 05/11/2026).
///
/// - Tarefa: +1 ao concluir, −1 ao reabrir ou apagar concluída.
/// - Dia do plano: a semana é calculada antes e depois de cada mudança
///   (sessão, finalizar, desfazer) e a diferença vai para `users.points`;
///   na cota semanal, um dia pode mudar o status de outro.
/// - O primeiro plano criado vira o principal.
class ProgressActions {
  ProgressActions(this._ref);

  final Ref _ref;

  /// Uma ação de cada vez: cada uma lê os pontos "antes", muda e lê o
  /// "depois". Duas ao mesmo tempo (toques rápidos) usariam o mesmo "antes"
  /// e somariam a diferença duas vezes.
  Future<void> _queue = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  DateTime get _now => _ref.read(clockProvider)();
  LocalDate get _today => LocalDate.fromDateTime(_now);
  String? get _uid => _ref.read(authStateProvider).value?.uid;

  Future<void> _addPoints(int delta) async {
    final uid = _uid;
    if (uid == null || delta == 0) return;
    await _ref.read(userProfileRepositoryProvider).addPoints(uid, delta);
  }

  // ---------- Tarefas ----------

  Future<void> setTaskCompleted(String taskId, bool completed) =>
      _serial(() async {
        final delta = await _ref
            .read(tasksRepositoryProvider)
            .setCompleted(taskId, completed);
        await _addPoints(delta);
      });

  Future<void> deleteTask(String taskId) => _serial(() async {
    final delta = await _ref.read(tasksRepositoryProvider).deleteTask(taskId);
    await _addPoints(delta);
  });

  // ---------- Planos ----------

  /// Cria o plano; se ainda não há principal, ele vira o principal.
  /// [makePrimary]: vira o principal de qualquer jeito ("Criar plano" no
  /// cartão do plano encerrado, sem outro ativo).
  Future<Plan> createPlan(
    Plan draft, {
    List<NewTopic> topics = const [],
    bool makePrimary = false,
  }) => _serial(() async {
    final plan = await _ref
        .read(plansRepositoryProvider)
        .createPlan(draft, topics: topics);
    final uid = _uid;
    if (uid == null) return plan;
    // Lê do repositório (não do provider em cache): dois planos criados em
    // seguida não podem os dois virar principal.
    final profiles = _ref.read(userProfileRepositoryProvider);
    final profile = await profiles.watchProfile(uid).first;
    if (profile != null && (makePrimary || profile.primaryPlanId == null)) {
      await profiles.setPrimaryPlan(uid, plan.id);
    }
    return plan;
  });

  /// "Retomar plano" (RF05): a pausa em aberto termina hoje (os dias
  /// pausados continuam fora da conta) e o plano volta a ativo. Hoje volta a
  /// contar (e, na cota semanal, pode mudar outros dias da semana): os
  /// pontos da semana são refeitos antes e depois.
  Future<void> resumePlan(String planId) {
    final today = _today;
    return _withWeekPoints(planId, {today}, () async {
      final repository = _ref.read(plansRepositoryProvider);
      final plan = await repository.watchPlan(planId).first;
      if (plan == null) return false;
      await repository.updatePlan(
        plan.copyWith(
          status: PlanStatus.active,
          pauses: [
            for (final p in plan.pauses)
              p.end == null ? PlanPause(start: p.start, end: today) : p,
          ],
        ),
      );
      return true;
    });
  }

  /// "Pausar plano" (RF05): vale a partir de hoje. Hoje sai da conta (e,
  /// na cota semanal, pode mudar outros dias): pontos refeitos.
  Future<void> pausePlan(String planId) {
    final today = _today;
    return _withWeekPoints(planId, {today}, () async {
      final repository = _ref.read(plansRepositoryProvider);
      final plan = await repository.watchPlan(planId).first;
      if (plan == null || plan.status != PlanStatus.active) return false;
      await repository.updatePlan(
        plan.copyWith(
          status: PlanStatus.paused,
          pauses: [
            ...plan.pauses,
            PlanPause(start: today),
          ],
        ),
      );
      return true;
    });
  }

  /// "Desfazer" do pausar: tira a pausa aberta hoje, como se não tivesse
  /// pausado (retomar faria hoje virar dia pausado).
  Future<void> undoPausePlan(String planId) {
    final today = _today;
    return _withWeekPoints(planId, {today}, () async {
      final repository = _ref.read(plansRepositoryProvider);
      final plan = await repository.watchPlan(planId).first;
      if (plan == null || plan.status != PlanStatus.paused) return false;
      await repository.updatePlan(
        plan.copyWith(
          status: PlanStatus.active,
          pauses: [
            for (final p in plan.pauses)
              if (!(p.start == today && p.end == null)) p,
          ],
        ),
      );
      return true;
    });
  }

  /// "Encerrar antes" (RF06): o plano termina hoje (`endedOn`) e o
  /// relatório final fica pronto. Sem volta. Os dias até hoje não mudam.
  Future<void> endPlanEarly(String planId) => _serial(() async {
    final repository = _ref.read(plansRepositoryProvider);
    final plan = await repository.watchPlan(planId).first;
    if (plan == null) return;
    final today = _today;
    final endedOn = today.isAfter(plan.endDate)
        ? plan.endDate
        : today.isBefore(plan.startDate)
        ? plan.startDate
        : today;
    await repository.updatePlan(
      plan.copyWith(
        status: PlanStatus.endedEarly,
        endedOn: () => endedOn,
        // Uma pausa em aberto termina junto, cobrindo o próprio dia do
        // encerramento (o fim da pausa não entra nela).
        pauses: [
          for (final p in plan.pauses)
            p.end == null
                ? PlanPause(start: p.start, end: endedOn.addDays(1))
                : p,
        ],
      ),
    );
  });

  /// "Arquivar": sai das listas principais. O `endedOn` continua.
  Future<void> archivePlan(String planId) => _serial(() async {
    final repository = _ref.read(plansRepositoryProvider);
    final plan = await repository.watchPlan(planId).first;
    if (plan == null) return;
    await repository.updatePlan(plan.copyWith(status: PlanStatus.archived));
  });

  /// "Desfazer" do arquivar: volta à situação de antes.
  Future<void> unarchivePlan(String planId, PlanStatus previous) =>
      _serial(() async {
        final repository = _ref.read(plansRepositoryProvider);
        final plan = await repository.watchPlan(planId).first;
        if (plan == null || plan.status != PlanStatus.archived) return;
        await repository.updatePlan(plan.copyWith(status: previous));
      });

  /// "Definir como principal" e "Escolher plano principal".
  Future<void> setPrimaryPlan(String planId) => _serial(() async {
    final uid = _uid;
    if (uid == null) return;
    await _ref.read(userProfileRepositoryProvider).setPrimaryPlan(uid, planId);
  });

  /// "Excluir plano" (confirmado antes; sem Desfazer): limpa o principal,
  /// se for este, e apaga tudo. Os pontos já somados ao nível ficam.
  Future<void> deletePlan(String planId) => _serial(() async {
    final uid = _uid;
    if (uid != null) {
      final profiles = _ref.read(userProfileRepositoryProvider);
      final profile = await profiles.watchProfile(uid).first;
      if (profile?.primaryPlanId == planId) {
        await profiles.setPrimaryPlan(uid, null);
      }
    }
    await _ref.read(plansRepositoryProvider).deletePlan(planId);
  });

  /// Liga o plano a um objetivo (ou tira, com `null`). Um objetivo por
  /// plano: ligar a outro muda o plano de objetivo.
  Future<void> setPlanGoal(String planId, String? goalId) => _serial(() async {
    final repository = _ref.read(plansRepositoryProvider);
    final plan = await repository.watchPlan(planId).first;
    if (plan == null) return;
    await repository.updatePlan(plan.copyWith(goalId: () => goalId));
  });

  /// Registra uma sessão de foco de [minutes] terminando agora (dividida à
  /// meia-noite, se for o caso).
  Future<void> addFocusMinutes(String planId, int minutes) async {
    final end = _now;
    await addSessions(
      planId,
      splitSessionByDay([
        ActiveInterval(end.subtract(Duration(minutes: minutes)), end),
      ]),
      source: SessionSource.focus,
    );
  }

  /// Grava as partes de uma sessão (já divididas à meia-noite) e ajusta os
  /// pontos das semanas tocadas. Devolve as sessões criadas (para o
  /// "Desfazer").
  Future<List<FocusSession>> addSessions(
    String planId,
    List<DaySegment> segments, {
    required SessionSource source,
    List<String> topicIds = const [],
    String? note,
  }) async {
    var created = const <FocusSession>[];
    await _withWeekPoints(planId, {for (final s in segments) s.day}, () async {
      created = await _ref
          .read(plansRepositoryProvider)
          .addSessions(
            planId,
            segments,
            source: source,
            topicIds: topicIds,
            note: note,
          );
      return created;
    });
    return created;
  }

  /// Apaga as sessões (ex.: "Desfazer" do salvar, "Excluir sessão") e
  /// ajusta os pontos.
  Future<void> deleteSessions(String planId, List<FocusSession> sessions) =>
      _withWeekPoints(planId, {for (final s in sessions) s.day}, () async {
        final repository = _ref.read(plansRepositoryProvider);
        for (final s in sessions) {
          await repository.deleteSession(planId, s.id);
        }
        return null;
      });

  /// "Editar sessão": troca dia, horário, tópicos ou nota e ajusta os
  /// pontos das semanas do antes e do depois.
  Future<void> updateSession(
    String planId,
    FocusSession before,
    FocusSession after,
  ) => _withWeekPoints(planId, {before.day, after.day}, () async {
    await _ref.read(plansRepositoryProvider).updateSession(planId, after);
    return null;
  });

  Future<void> finalizeDay(String planId, LocalDate day) =>
      _withWeekPoints(planId, {day}, () {
        return _ref.read(plansRepositoryProvider).finalizeDay(planId, day);
      });

  /// "Desfazer" da Snackbar (RF17).
  Future<void> undoFinalizeDay(String planId, LocalDate day) =>
      _withWeekPoints(planId, {day}, () {
        return _ref.read(plansRepositoryProvider).undoFinalizeDay(planId, day);
      });

  /// Roda [change] e soma ao perfil a diferença de pontos das semanas de
  /// [days], na fila (uma ação de cada vez).
  Future<void> _withWeekPoints(
    String planId,
    Set<LocalDate> days,
    Future<Object?> Function() change,
  ) => _serial(() async {
    final weeks = {for (final d in days) NexoWeek.startOf(d)};
    final before = await _weeksPoints(planId, weeks);
    await change();
    final after = await _weeksPoints(planId, weeks);
    await _addPoints(after - before);
  });

  Future<int> _weeksPoints(String planId, Set<LocalDate> weeks) async {
    final snapshot = await _snapshot(planId);
    if (snapshot == null) return 0;
    return weeks.fold<int>(
      0,
      (sum, week) => sum + planWeekPoints(snapshot, week, today: _today),
    );
  }

  Future<PlanSnapshot?> _snapshot(String planId) async {
    final repository = _ref.read(plansRepositoryProvider);
    final plan = await repository.watchPlan(planId).first;
    if (plan == null) return null;
    return PlanSnapshot(
      plan: plan,
      versions: await repository.watchVersions(planId).first,
      days: await repository.watchDays(planId).first,
    );
  }
}

final progressActionsProvider = Provider<ProgressActions>(ProgressActions.new);
