import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/data/data_failure.dart';
import '../../../core/data/firestore_access.dart';
import '../../../core/domain/edit_window.dart';
import '../../../core/domain/local_date.dart';
import '../../focus/domain/focus_session.dart';
import '../../focus/domain/session_split.dart';
import '../domain/plan.dart';
import '../domain/plan_schedule.dart';
import 'plans_repository.dart';

/// `users/{uid}/plans` e as subcoleções no Firestore (regras v0.9):
/// - criar plano: o plano, a versão inicial e os tópicos num lote só;
/// - `scheduleVersions` é imutável: cada edição de meta ou frequência cria
///   uma versão nova (id automático) e atualiza a cópia no plano, no mesmo
///   lote. No empate de `effectiveFrom`, vale a criada por último (as
///   versões chegam na ordem do `createdAt`);
/// - sessão e `doneMinutes` do dia no mesmo lote. O dia novo leva todos os
///   campos (`finalizedAt: null` incluído), como as regras pedem; o que já
///   existe só troca a soma;
/// - janela de 7 dias para sessões e dias, conferida antes de gravar;
/// - excluir plano: `status: deleting` primeiro (sem volta, libera apagar o
///   histórico) e depois os filhos em lotes de até 500 e o plano. A limpeza
///   lê do servidor: sem internet, termina na próxima abertura
///   ([resumeDeletions]).
///
/// As gravações do dia a dia não esperam o servidor ([FirestoreAccess.send]).
class FirestorePlansRepository implements PlansRepository {
  FirestorePlansRepository(
    this._access, {
    required String? uid,
    required this.clock,
  }) : _user = UserDocs(uid);

  final FirestoreAccess _access;
  final UserDocs _user;

  /// Relógio da janela de 7 dias.
  final DateTime Function() clock;

  LocalDate get _today => LocalDate.fromDateTime(clock());

  /// Subcoleções do plano, na ordem em que a exclusão apaga.
  static const children = ['sessions', 'days', 'topics', 'scheduleVersions'];

  CollectionReference<Map<String, dynamic>> _plans(FirebaseFirestore db) =>
      _user.collection(db, 'plans');

  DocumentReference<Map<String, dynamic>> _plan(
    FirebaseFirestore db,
    String planId,
  ) => _plans(db).doc(planId);

  CollectionReference<Map<String, dynamic>> _child(
    FirebaseFirestore db,
    String planId,
    String name,
  ) => _plan(db, planId).collection(name);

  // ---------- Leitura ----------

  @override
  Stream<List<Plan>> watchPlans() {
    if (!_user.signedIn) return Stream.value(const []);
    return _access
        .watchDocs(_plans)
        .map(
          (docs) =>
              [for (final doc in docs) ?planFromFirestore(doc.id, doc.data())]
                ..removeWhere((p) => p.status == PlanStatus.deleting)
                ..sort((a, b) => a.startDate.compareTo(b.startDate)),
        );
  }

  @override
  Stream<Plan?> watchPlan(String planId) {
    if (!_user.signedIn) return Stream.value(null);
    return _access
        .watchDoc((db) => _plan(db, planId))
        .map((snapshot) => planFromFirestore(snapshot.id, snapshot.data()));
  }

  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> _watchChild(
    String planId,
    String name,
  ) {
    if (!_user.signedIn) return Stream.value(const []);
    return _access.watchDocs((db) => _child(db, planId, name));
  }

  @override
  Stream<List<ScheduleVersion>> watchVersions(String planId) =>
      _watchChild(planId, 'scheduleVersions').map((docs) {
        final ordered = [...docs]..sort(compareByCreatedAt);
        return [
          for (final doc in ordered) ?scheduleVersionFromFirestore(doc.data()),
        ];
      });

  @override
  Stream<List<PlanTopic>> watchTopics(String planId) =>
      _watchChild(planId, 'topics').map((docs) {
        final ordered = [...docs]..sort(compareByCreatedAt);
        return [
          for (final doc in ordered) ?topicFromFirestore(doc.id, doc.data()),
        ];
      });

  @override
  Stream<List<PlanDay>> watchDays(String planId) =>
      _watchChild(planId, 'days').map(
        (docs) =>
            [for (final doc in docs) ?dayFromFirestore(doc.id, doc.data())]
              ..sort((a, b) => a.day.compareTo(b.day)),
      );

  @override
  Stream<List<FocusSession>> watchSessions(String planId) =>
      _watchChild(planId, 'sessions').map(
        (docs) => [
          for (final doc in docs)
            ?sessionFromFirestore(planId, doc.id, doc.data()),
        ]..sort((a, b) => a.startAt.compareTo(b.startAt)),
      );

  // ---------- Plano, versões e tópicos ----------

  /// O plano como o aparelho o conhece agora. Recusa o que não existe ou
  /// está sendo excluído (as regras negariam).
  Future<Plan> _openPlan(String planId) async {
    final plan = await watchPlan(planId).first;
    if (plan == null || plan.status == PlanStatus.deleting) {
      throw StateError('Plano $planId não existe.');
    }
    return plan;
  }

  @override
  Future<Plan> createPlan(
    Plan draft, {
    List<NewTopic> topics = const [],
  }) async {
    late Plan plan;
    await _access.send((db) {
      final ref = _plans(db).doc();
      plan = Plan(
        id: ref.id,
        name: draft.name,
        startDate: draft.startDate,
        endDate: draft.endDate,
        frequency: draft.frequency,
        dailyGoalMinutes: draft.dailyGoalMinutes,
        goalId: draft.goalId,
        studyTime: draft.studyTime,
        reminderBefore: draft.reminderBefore,
      );
      final batch = db.batch()
        ..set(ref, {...plan.toMap(), ...createdStamps()})
        ..set(
          _child(db, ref.id, 'scheduleVersions').doc(),
          scheduleVersionToFirestore(
            ScheduleVersion(
              effectiveFrom: plan.startDate,
              frequency: plan.frequency,
              dailyGoalMinutes: plan.dailyGoalMinutes,
            ),
          ),
        );
      for (final t in topics) {
        final topicRef = _child(db, ref.id, 'topics').doc();
        final topic = PlanTopic(
          id: topicRef.id,
          name: t.name,
          subjectId: t.subjectId,
        );
        batch.set(topicRef, {...topic.toMap(), ...createdStamps()});
      }
      return batch.commit();
    });
    return plan;
  }

  @override
  Future<void> updatePlan(Plan plan) => _access.send(
    (db) => _plan(db, plan.id).update({...plan.toMap(), ...updatedStamp()}),
  );

  @override
  Future<void> addScheduleVersion(
    String planId,
    ScheduleVersion version,
  ) async {
    await _openPlan(planId);
    await _access.send(
      (db) =>
          (db.batch()
                ..set(
                  _child(db, planId, 'scheduleVersions').doc(),
                  scheduleVersionToFirestore(version),
                )
                ..update(_plan(db, planId), {
                  'frequency': version.frequency.toMap(),
                  'dailyGoalMinutes': version.dailyGoalMinutes,
                  ...updatedStamp(),
                }))
              .commit(),
    );
  }

  @override
  Future<PlanTopic> addTopic(
    String planId,
    String name, {
    String? subjectId,
  }) async {
    await _openPlan(planId);
    late PlanTopic topic;
    await _access.send((db) {
      final ref = _child(db, planId, 'topics').doc();
      topic = PlanTopic(id: ref.id, name: name, subjectId: subjectId);
      return ref.set({...topic.toMap(), ...createdStamps()});
    });
    return topic;
  }

  @override
  Future<void> updateTopic(String planId, PlanTopic topic) async {
    final exists = await _access.run(
      (db) async => (await _child(
        db,
        planId,
        'topics',
      ).doc(topic.id).snapshots().first).exists,
    );
    if (!exists) return;
    await _access.send(
      (db) => _child(
        db,
        planId,
        'topics',
      ).doc(topic.id).update({...topic.toMap(), ...updatedStamp()}),
    );
  }

  @override
  Future<void> deleteTopic(String planId, String topicId) =>
      _access.send((db) => _child(db, planId, 'topics').doc(topicId).delete());

  // ---------- Excluir plano ----------

  @override
  Future<void> deletePlan(String planId) async {
    final plan = await watchPlan(planId).first;
    if (plan == null) return;
    if (plan.status != PlanStatus.deleting) {
      // Sem volta: as regras passam a negar alterar o plano e criar filhos,
      // e liberam apagar o histórico. O plano some das listas na hora.
      await _access.send(
        (db) => _plan(
          db,
          planId,
        ).update({'status': PlanStatus.deleting.value, ...updatedStamp()}),
      );
    }
    unawaited(_quietly(() => purgePlan(planId)));
  }

  /// Apaga as subcoleções em lotes e, por último, o plano. Espera o
  /// servidor; sem internet, lança `DataFailure(network)`. Quem chama já
  /// marcou o plano (`deleting`) ou a conta (`deletionRequestedAt`) e
  /// limpou o `primaryPlanId`, se apontava para ele.
  Future<void> purgePlan(String planId) => _access.run((db) async {
    for (final name in children) {
      await deleteAllDocs(db, _child(db, planId, name));
    }
    await _plan(db, planId).delete();
  });

  /// Retoma as exclusões de plano que ficaram no meio (app fechado ou sem
  /// internet).
  Future<void> resumeDeletions() async {
    if (!_user.signedIn) return;
    final ids = await _access.run((db) async {
      final page = await _plans(db)
          .where('status', isEqualTo: PlanStatus.deleting.value)
          .get(const GetOptions(source: Source.server));
      return [for (final doc in page.docs) doc.id];
    });
    for (final id in ids) {
      await purgePlan(id);
    }
  }

  /// [resumeDeletions] sem esperar: chamado quando o repositório da conta é
  /// criado (a cada login e abertura do app).
  void resumeDeletionsInBackground() => unawaited(_quietly(resumeDeletions));

  /// Roda a limpeza em segundo plano. Sem internet, fica para a próxima
  /// abertura; os outros erros são registrados.
  static Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } on DataFailure catch (e, stack) {
      if (e.code != DataFailureCode.network) _report(e, stack);
    } on Object catch (e, stack) {
      _report(e, stack);
    }
  }

  // ---------- Sessões e dias ----------

  void _checkWindow(LocalDate day, String action) {
    if (!isWithinEditWindow(day, today: _today)) {
      throw StateError('$action só até 7 dias atrás.');
    }
  }

  /// O dia como o aparelho o conhece agora: se o documento existe e as
  /// sessões dele.
  Future<Map<LocalDate, ({bool exists, List<FocusSession> sessions})>>
  _daysState(String planId, Set<LocalDate> days) => _access.run(
    (db) async => {
      for (final day in days)
        day: (
          exists: (await _dayRef(db, planId, day).snapshots().first).exists,
          sessions: [
            for (final doc in (await _child(
              db,
              planId,
              'sessions',
            ).where('day', isEqualTo: day.toIso()).snapshots().first).docs)
              ?sessionFromFirestore(planId, doc.id, doc.data()),
          ],
        ),
    },
  );

  DocumentReference<Map<String, dynamic>> _dayRef(
    FirebaseFirestore db,
    String planId,
    LocalDate day,
  ) => _child(db, planId, 'days').doc(day.toIso());

  /// O dia com a soma refeita, no lote da sessão.
  void _putDay(
    WriteBatch batch,
    DocumentReference<Map<String, dynamic>> ref, {
    required bool exists,
    required Iterable<FocusSession> sessions,
  }) {
    final minutes = dayDoneMinutes(sessions);
    if (exists) {
      batch.update(ref, {'doneMinutes': minutes, ...updatedStamp()});
    } else {
      batch.set(ref, {
        'doneMinutes': minutes,
        'finalizedAt': null,
        ...createdStamps(),
      });
    }
  }

  Future<FocusSession?> _session(String planId, String sessionId) =>
      _access.run((db) async {
        final snapshot = await _child(
          db,
          planId,
          'sessions',
        ).doc(sessionId).snapshots().first;
        return sessionFromFirestore(planId, snapshot.id, snapshot.data());
      });

  @override
  Future<List<FocusSession>> addSessions(
    String planId,
    List<DaySegment> segments, {
    required SessionSource source,
    List<String> topicIds = const [],
    String? note,
  }) async {
    await _openPlan(planId);
    for (final segment in segments) {
      _checkWindow(segment.day, 'Sessões são registradas');
    }
    final days = {for (final s in segments) s.day};
    final state = await _daysState(planId, days);
    late List<FocusSession> created;
    await _access.send((db) {
      final sessions = _child(db, planId, 'sessions');
      created = [
        for (final segment in segments)
          FocusSession(
            id: sessions.doc().id,
            planId: planId,
            startAt: segment.startAt,
            endAt: segment.endAt,
            durationSeconds: segment.durationSeconds,
            source: source,
            day: segment.day,
            topicIds: topicIds,
            note: note,
          ),
      ];
      final batch = db.batch();
      for (final session in created) {
        batch.set(sessions.doc(session.id), {
          ...sessionToFirestore(session),
          ...createdStamps(),
        });
      }
      for (final day in days) {
        _putDay(
          batch,
          _dayRef(db, planId, day),
          exists: state[day]!.exists,
          sessions: [
            ...state[day]!.sessions,
            ...created.where((s) => s.day == day),
          ],
        );
      }
      return batch.commit();
    });
    return created;
  }

  @override
  Future<void> updateSession(String planId, FocusSession session) async {
    final before = await _session(planId, session.id);
    if (before == null) throw StateError('Sessão ${session.id} não existe.');
    final days = {before.day, session.day};
    for (final day in days) {
      _checkWindow(day, 'Sessões são editadas');
    }
    final state = await _daysState(planId, days);
    await _access.send((db) {
      final batch = db.batch()
        ..update(_child(db, planId, 'sessions').doc(session.id), {
          ...sessionToFirestore(session),
          ...updatedStamp(),
        });
      for (final day in days) {
        _putDay(
          batch,
          _dayRef(db, planId, day),
          exists: state[day]!.exists,
          sessions: [
            for (final s in state[day]!.sessions)
              if (s.id != session.id) s,
            if (session.day == day) session,
          ],
        );
      }
      return batch.commit();
    });
  }

  @override
  Future<void> deleteSession(String planId, String sessionId) async {
    final session = await _session(planId, sessionId);
    if (session == null) return;
    _checkWindow(session.day, 'Sessões são apagadas');
    final state = (await _daysState(planId, {session.day}))[session.day]!;
    await _access.send((db) {
      final batch = db.batch()
        ..delete(_child(db, planId, 'sessions').doc(sessionId));
      _putDay(
        batch,
        _dayRef(db, planId, session.day),
        exists: state.exists,
        sessions: [
          for (final s in state.sessions)
            if (s.id != sessionId) s,
        ],
      );
      return batch.commit();
    });
  }

  @override
  Future<void> finalizeDay(String planId, LocalDate day) async {
    await _openPlan(planId);
    _checkWindow(day, 'Dias são finalizados');
    final state = (await _daysState(planId, {day}))[day]!;
    await _access.send((db) {
      final ref = _dayRef(db, planId, day);
      if (state.exists) {
        return ref.update({
          'finalizedAt': FieldValue.serverTimestamp(),
          ...updatedStamp(),
        });
      }
      return ref.set({
        'doneMinutes': dayDoneMinutes(state.sessions),
        'finalizedAt': FieldValue.serverTimestamp(),
        ...createdStamps(),
      });
    });
  }

  @override
  Future<void> undoFinalizeDay(String planId, LocalDate day) async {
    await _openPlan(planId);
    // Mesma janela das regras para desfazer.
    _checkWindow(day, 'Dias são desfeitos');
    final exists = await _access.run(
      (db) async => (await _dayRef(db, planId, day).snapshots().first).exists,
    );
    if (!exists) return;
    // finalizedAt: null, nunca FieldValue.delete(): as regras pedem o campo.
    await _access.send(
      (db) => _dayRef(
        db,
        planId,
        day,
      ).update({'finalizedAt': null, ...updatedStamp()}),
    );
  }
}

void _report(Object error, StackTrace stack) => FlutterError.reportError(
  FlutterErrorDetails(exception: error, stack: stack, library: 'nexo dados'),
);

// ---------- Mapas dos documentos ----------

/// `plans/{id}` → [Plan]; `null` se não existe ou não passa nas regras do
/// app (não quebra a lista).
Plan? planFromFirestore(String id, Map<String, dynamic>? data) {
  if (data == null) return null;
  try {
    return Plan.fromMap(id, data);
  } on Object {
    return null;
  }
}

Map<String, Object?> scheduleVersionToFirestore(ScheduleVersion version) => {
  'effectiveFrom': version.effectiveFrom.toIso(),
  'frequency': version.frequency.toMap(),
  'dailyGoalMinutes': version.dailyGoalMinutes,
  // Versão imutável: só createdAt, sem updatedAt.
  'createdAt': FieldValue.serverTimestamp(),
};

ScheduleVersion? scheduleVersionFromFirestore(Map<String, dynamic>? data) {
  if (data == null) return null;
  try {
    return ScheduleVersion(
      effectiveFrom: LocalDate.parse(data['effectiveFrom'] as String),
      frequency: PlanFrequency.fromMap(
        (data['frequency'] as Map).cast<String, Object?>(),
      ),
      dailyGoalMinutes: intField(data['dailyGoalMinutes'])!,
    );
  } on Object {
    return null;
  }
}

PlanTopic? topicFromFirestore(String id, Map<String, dynamic>? data) {
  if (data == null) return null;
  try {
    return PlanTopic.fromMap(id, data);
  } on Object {
    return null;
  }
}

/// `days/{AAAA-MM-DD}` → [PlanDay]. O id do documento é a data.
PlanDay? dayFromFirestore(String id, Map<String, dynamic>? data) {
  final day = localDateField(id);
  if (data == null || day == null) return null;
  try {
    return PlanDay(
      day: day,
      doneMinutes: intField(data['doneMinutes']) ?? 0,
      finalizedAt: timestampField(data['finalizedAt']),
    );
  } on Object {
    return null;
  }
}

/// Campos da sessão (sem os carimbos).
Map<String, Object?> sessionToFirestore(FocusSession session) => {
  'startAt': Timestamp.fromDate(session.startAt),
  'endAt': Timestamp.fromDate(session.endAt),
  'durationSeconds': session.durationSeconds,
  'source': session.source.value,
  'day': session.day.toIso(),
  'topicIds': session.topicIds,
  'note': session.note,
};

FocusSession? sessionFromFirestore(
  String planId,
  String id,
  Map<String, dynamic>? data,
) {
  if (data == null) return null;
  try {
    final topicIds = data['topicIds'];
    // Sessão de antes da v0.9: um tópico só, em topicId.
    final legacy = data['topicId'];
    return FocusSession(
      id: id,
      planId: planId,
      startAt: timestampField(data['startAt'])!,
      endAt: timestampField(data['endAt'])!,
      durationSeconds: intField(data['durationSeconds'])!,
      source: SessionSource.fromValue(data['source'] as String),
      day: LocalDate.parse(data['day'] as String),
      topicIds: topicIds is List
          ? topicIds.cast<String>().toList()
          : [if (legacy is String) legacy],
      note: data['note'] as String?,
    );
  } on Object {
    return null;
  }
}
