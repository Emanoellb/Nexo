import '../../../core/data/in_memory_store.dart';
import '../../../core/domain/edit_window.dart';
import '../../../core/domain/local_date.dart';
import '../../focus/domain/focus_session.dart';
import '../../focus/domain/session_split.dart';
import '../domain/plan.dart';
import '../domain/plan_schedule.dart';
import 'plans_repository.dart';

/// Planos em memória para a prototipação. Aplica as mesmas regras que o
/// app terá de aplicar com o Firestore (lote plano + versão, `doneMinutes`
/// junto com a sessão, janela de 7 dias).
class FakePlansRepository implements PlansRepository {
  FakePlansRepository({required this.clock});

  /// Relógio injetável (testes usam horário fixo).
  final DateTime Function() clock;
  final _ids = FakeIds('plano');
  final _plans = InMemoryStore<Plan>(const [], (p) => p.id);
  final _versions = <String, List<ScheduleVersion>>{};
  final _topics = InMemoryStore<({String planId, PlanTopic topic})>(
    const [],
    (t) => '${t.planId}/${t.topic.id}',
  );
  final _days = InMemoryStore<({String planId, PlanDay day})>(
    const [],
    (d) => '${d.planId}/${d.day.day.toIso()}',
  );
  final _sessions = InMemoryStore<FocusSession>(
    const [],
    (s) => '${s.planId}/${s.id}',
  );
  final _versionsChanged = InMemoryStore<String>(const [], (id) => id);

  LocalDate get _today => LocalDate.fromDateTime(clock());

  // ---------- Leitura ----------

  @override
  Stream<List<Plan>> watchPlans() => _plans.watch(
    where: (p) => p.status != PlanStatus.deleting,
    sort: (a, b) => a.startDate.compareTo(b.startDate),
  );

  @override
  Stream<Plan?> watchPlan(String planId) =>
      _plans.watch(where: (p) => p.id == planId).map((l) => l.firstOrNull);

  @override
  Stream<List<ScheduleVersion>> watchVersions(String planId) => _versionsChanged
      .watch()
      .map((_) => List.unmodifiable(_versions[planId] ?? const []));

  @override
  Stream<List<PlanTopic>> watchTopics(String planId) => _topics
      .watch(where: (t) => t.planId == planId)
      .map((list) => [for (final t in list) t.topic]);

  @override
  Stream<List<PlanDay>> watchDays(String planId) => _days
      .watch(
        where: (d) => d.planId == planId,
        sort: (a, b) => a.day.day.compareTo(b.day.day),
      )
      .map((list) => [for (final d in list) d.day]);

  @override
  Stream<List<FocusSession>> watchSessions(String planId) => _sessions.watch(
    where: (s) => s.planId == planId,
    sort: (a, b) => a.startAt.compareTo(b.startAt),
  );

  // ---------- Plano, versões e tópicos ----------

  @override
  Future<Plan> createPlan(
    Plan draft, {
    List<String> topicNames = const [],
  }) async {
    final plan = Plan(
      id: _ids.next(),
      name: draft.name,
      startDate: draft.startDate,
      endDate: draft.endDate,
      frequency: draft.frequency,
      dailyGoalMinutes: draft.dailyGoalMinutes,
      goalId: draft.goalId,
      reminder: draft.reminder,
    );
    _plans.put(plan);
    _setVersions(plan.id, [
      ScheduleVersion(
        effectiveFrom: plan.startDate,
        frequency: plan.frequency,
        dailyGoalMinutes: plan.dailyGoalMinutes,
      ),
    ]);
    for (final name in topicNames) {
      await addTopic(plan.id, name);
    }
    return plan;
  }

  @override
  Future<void> updatePlan(Plan plan) async => _plans.put(plan);

  @override
  Future<void> addScheduleVersion(
    String planId,
    ScheduleVersion version,
  ) async {
    final plan = _requirePlan(planId);
    _setVersions(planId, [...?_versions[planId], version]);
    _plans.put(
      plan.copyWith(
        frequency: version.frequency,
        dailyGoalMinutes: version.dailyGoalMinutes,
      ),
    );
  }

  void _setVersions(String planId, List<ScheduleVersion> versions) {
    _versions[planId] = List.unmodifiable(versions);
    _versionsChanged.put(planId);
  }

  @override
  Future<PlanTopic> addTopic(
    String planId,
    String name, {
    String? subjectId,
  }) async {
    _requirePlan(planId);
    final topic = PlanTopic(id: _ids.next(), name: name, subjectId: subjectId);
    _topics.put((planId: planId, topic: topic));
    return topic;
  }

  @override
  Future<void> renameTopic(String planId, String topicId, String name) async {
    final current = _topics.get('$planId/$topicId')!.topic;
    _topics.put((
      planId: planId,
      topic: PlanTopic(id: topicId, name: name, subjectId: current.subjectId),
    ));
  }

  @override
  Future<void> deleteTopic(String planId, String topicId) async =>
      _topics.remove('$planId/$topicId');

  // ---------- Sessões e dias ----------

  @override
  Future<List<FocusSession>> addSessions(
    String planId,
    List<DaySegment> segments, {
    required SessionSource source,
    String? topicId,
    String? note,
  }) async {
    _requirePlan(planId);
    for (final segment in segments) {
      if (!isWithinEditWindow(segment.day, today: _today)) {
        throw StateError('Sessões só podem ser registradas até 7 dias atrás.');
      }
    }
    final created = [
      for (final segment in segments)
        FocusSession(
          id: _ids.next(),
          planId: planId,
          startAt: segment.startAt,
          endAt: segment.endAt,
          durationSeconds: segment.durationSeconds,
          source: source,
          day: segment.day,
          topicId: topicId,
          note: note,
        ),
    ];
    _sessions.putAll(created);
    for (final day in {for (final s in created) s.day}) {
      _recomputeDay(planId, day);
    }
    return created;
  }

  @override
  Future<void> deleteSession(String planId, String sessionId) async {
    final session = _sessions.get('$planId/$sessionId');
    if (session == null) return;
    if (!isWithinEditWindow(session.day, today: _today)) {
      throw StateError('Sessões só podem ser apagadas até 7 dias atrás.');
    }
    _sessions.remove('$planId/$sessionId');
    _recomputeDay(planId, session.day);
  }

  /// `doneMinutes` = soma das sessões do dia (mesmo lote que a sessão).
  void _recomputeDay(String planId, LocalDate day) {
    final seconds = _sessions.all
        .where((s) => s.planId == planId && s.day == day)
        .fold<int>(0, (sum, s) => sum + s.durationSeconds);
    final minutes = (seconds ~/ 60).clamp(0, 1440);
    final current = _days.get('$planId/${day.toIso()}')?.day;
    _days.put((
      planId: planId,
      day: current == null
          ? PlanDay(day: day, doneMinutes: minutes)
          : current.copyWith(doneMinutes: minutes),
    ));
  }

  @override
  Future<void> finalizeDay(String planId, LocalDate day) async {
    _requirePlan(planId);
    if (!isWithinEditWindow(day, today: _today)) {
      throw StateError('Dias só podem ser finalizados até 7 dias atrás.');
    }
    final current = _days.get('$planId/${day.toIso()}')?.day;
    _days.put((
      planId: planId,
      day: (current ?? PlanDay(day: day, doneMinutes: 0)).copyWith(
        finalizedAt: clock(),
      ),
    ));
  }

  @override
  Future<void> undoFinalizeDay(String planId, LocalDate day) async {
    final current = _days.get('$planId/${day.toIso()}')?.day;
    if (current == null) return;
    _days.put((planId: planId, day: current.copyWith(clearFinalized: true)));
  }

  Plan _requirePlan(String planId) {
    final plan = _plans.get(planId);
    if (plan == null) throw StateError('Plano $planId não existe.');
    return plan;
  }

  void dispose() {
    _plans.dispose();
    _topics.dispose();
    _days.dispose();
    _sessions.dispose();
    _versionsChanged.dispose();
  }
}
