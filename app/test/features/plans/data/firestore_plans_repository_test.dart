import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/firestore_access.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/focus/domain/focus_session.dart';
import 'package:nexo/features/focus/domain/session_split.dart';
import 'package:nexo/features/plans/data/firestore_plans_repository.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';

import '../../../helpers/firestore_test_support.dart';

const _uid = 'u1';
const _today = LocalDate(2026, 11, 11);

DaySegment _segment(LocalDate day, int hour, int minutes) {
  final start = DateTime(day.year, day.month, day.day, hour);
  return DaySegment(
    day: day,
    startAt: start,
    endAt: start.add(Duration(minutes: minutes)),
    durationSeconds: minutes * 60,
  );
}

void main() {
  late FakeFirebaseFirestore db;
  late FirestorePlansRepository repository;

  CollectionReference<Map<String, dynamic>> plans() =>
      db.collection('users').doc(_uid).collection('plans');

  CollectionReference<Map<String, dynamic>> child(String planId, String name) =>
      plans().doc(planId).collection(name);

  Future<Map<String, dynamic>> dayData(String planId, LocalDate day) async =>
      (await child(planId, 'days').doc(day.toIso()).get()).data()!;

  Future<Plan> newPlan({List<({String name, String? subjectId})>? topics}) =>
      repository.createPlan(
        Plan(
          id: '',
          name: 'Concurso',
          startDate: const LocalDate(2026, 11, 10),
          endDate: const LocalDate(2027, 3, 1),
          frequency: const DailyFrequency(),
          dailyGoalMinutes: 60,
        ),
        topics: topics ?? const [],
      );

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = FirestorePlansRepository(
      FirestoreAccess.of(db),
      uid: _uid,
      clock: () => DateTime(2026, 11, 11, 10),
    );
  });

  group('criar plano', () {
    test('plano, versão inicial e tópicos no mesmo lote, nos campos das '
        'regras', () async {
      final plan = await newPlan(
        topics: [
          (name: 'Português', subjectId: null),
          (name: 'Direito', subjectId: 's1'),
        ],
      );
      await settle();

      final doc = (await plans().doc(plan.id).get()).data()!;
      expectValidCreate(
        doc,
        allowed: RulesFields.plan,
        required: RulesFields.planRequired,
      );
      expect(doc['status'], 'active');
      expect(doc['startDate'], '2026-11-10');

      final versions = await child(plan.id, 'scheduleVersions').get();
      expect(versions.docs, hasLength(1));
      final version = versions.docs.single.data();
      expect(version.keys.toSet(), RulesFields.version);
      expect(version['effectiveFrom'], '2026-11-10');
      expect(version['dailyGoalMinutes'], 60);

      final topics = await child(plan.id, 'topics').get();
      expect(topics.docs, hasLength(2));
      for (final t in topics.docs) {
        expectValidCreate(
          t.data(),
          allowed: RulesFields.topic,
          required: {'name', 'createdAt', 'updatedAt'},
        );
      }

      expect((await repository.watchPlans().first).single.id, plan.id);
      expect(await repository.watchTopics(plan.id).first, hasLength(2));
    });

    test('nova meta: versão nova e a cópia no plano, no mesmo lote', () async {
      final plan = await newPlan();
      await settle();
      final before = await agedData(plans().doc(plan.id));
      await repository.addScheduleVersion(
        plan.id,
        ScheduleVersion(
          effectiveFrom: const LocalDate(2026, 11, 12),
          frequency: WeekdaysFrequency({1, 3, 5}),
          dailyGoalMinutes: 90,
        ),
      );
      await settle();

      final versions = await repository.watchVersions(plan.id).first;
      expect(versions, hasLength(2));
      final after = (await plans().doc(plan.id).get()).data()!;
      expectValidUpdate(before, after, allowed: RulesFields.plan);
      expect(after['dailyGoalMinutes'], 90);
      expect(after['frequency'], {
        'type': 'weekdays',
        'weekdays': [1, 3, 5],
      });
    });

    test('versões na ordem do createdAt; a pendente por último', () async {
      final plan = await newPlan();
      await settle();
      final versions = child(plan.id, 'scheduleVersions');
      for (final v in (await versions.get()).docs) {
        await v.reference.delete();
      }
      Map<String, Object?> version(int minutes, Object? createdAt) => {
        'effectiveFrom': '2026-11-12',
        'frequency': {'type': 'daily'},
        'dailyGoalMinutes': minutes,
        'createdAt': ?createdAt,
      };
      await versions.doc('a').set(version(30, null));
      await versions.doc('b').set(version(45, Timestamp(2000, 0)));
      await versions.doc('c').set(version(15, Timestamp(1000, 0)));

      final ordered = await repository.watchVersions(plan.id).first;
      expect([for (final v in ordered) v.dailyGoalMinutes], [15, 45, 30]);
    });

    test('sem login: lista vazia e gravar é erro', () async {
      final signedOut = FirestorePlansRepository(
        FirestoreAccess.of(db),
        uid: null,
        clock: DateTime.now,
      );
      expect(await signedOut.watchPlans().first, isEmpty);
      await expectLater(
        signedOut.createPlan(
          Plan(
            id: '',
            name: 'X',
            startDate: _today,
            endDate: _today,
            frequency: const DailyFrequency(),
            dailyGoalMinutes: 30,
          ),
        ),
        throwsStateError,
      );
    });
  });

  group('sessões e dias', () {
    late Plan plan;

    setUp(() async {
      plan = await newPlan();
      await settle();
    });

    test('a sessão e o dia novo (todos os campos) no mesmo lote', () async {
      final created = await repository.addSessions(plan.id, [
        _segment(_today, 8, 30),
      ], source: SessionSource.focus);
      await settle();

      final session = (await child(
        plan.id,
        'sessions',
      ).doc(created.single.id).get()).data()!;
      expectValidCreate(
        session,
        allowed: RulesFields.session,
        required: RulesFields.sessionRequired,
      );
      expect(session['startAt'], isA<Timestamp>());
      expect(session['day'], '2026-11-11');
      expect(session['source'], 'focus');

      final day = await dayData(plan.id, _today);
      expect(day.keys.toSet(), RulesFields.day);
      expect(day['doneMinutes'], 30);
      expect(day.containsKey('finalizedAt'), isTrue);
      expect(day['finalizedAt'], isNull);
    });

    test('segunda sessão no dia: só a soma e o updatedAt mudam', () async {
      await repository.addSessions(plan.id, [
        _segment(_today, 8, 30),
      ], source: SessionSource.focus);
      await settle();
      final dayRef = child(plan.id, 'days').doc(_today.toIso());
      await dayRef.update({'createdAt': oldStamp, 'updatedAt': oldStamp});
      final before = await dayData(plan.id, _today);

      await repository.addSessions(plan.id, [
        _segment(_today, 9, 45),
      ], source: SessionSource.manual);
      await settle();
      final after = await dayData(plan.id, _today);
      expectValidUpdate(before, after, allowed: RulesFields.day);
      expect(after['doneMinutes'], 75);
    });

    test('sessão que cruza a meia-noite soma em cada dia', () async {
      final yesterday = _today.addDays(-1);
      await repository.addSessions(plan.id, [
        _segment(yesterday, 23, 30),
        _segment(_today, 0, 45),
      ], source: SessionSource.focus);
      await settle();
      expect((await dayData(plan.id, yesterday))['doneMinutes'], 30);
      expect((await dayData(plan.id, _today))['doneMinutes'], 45);
      final days = await repository.watchDays(plan.id).first;
      expect([for (final d in days) d.day], [yesterday, _today]);
    });

    test('fora da janela de 7 dias: recusa antes de gravar', () async {
      await expectLater(
        repository.addSessions(plan.id, [
          _segment(_today.addDays(-8), 8, 30),
        ], source: SessionSource.manual),
        throwsStateError,
      );
      await settle();
      expect((await child(plan.id, 'sessions').get()).docs, isEmpty);
    });

    test('editar a sessão refaz os dois dias', () async {
      final yesterday = _today.addDays(-1);
      final created = await repository.addSessions(plan.id, [
        _segment(_today, 8, 30),
      ], source: SessionSource.manual);
      await settle();
      final moved = FocusSession(
        id: created.single.id,
        planId: plan.id,
        startAt: DateTime(2026, 11, 10, 8),
        endAt: DateTime(2026, 11, 10, 8, 50),
        durationSeconds: 50 * 60,
        source: SessionSource.manual,
        day: yesterday,
        note: 'Revisão',
      );
      final before = await agedData(child(plan.id, 'sessions').doc(moved.id));
      await repository.updateSession(plan.id, moved);
      await settle();

      final after = (await child(
        plan.id,
        'sessions',
      ).doc(moved.id).get()).data()!;
      expectValidUpdate(before, after, allowed: RulesFields.session);
      expect((await dayData(plan.id, _today))['doneMinutes'], 0);
      expect((await dayData(plan.id, yesterday))['doneMinutes'], 50);
    });

    test('apagar a sessão desconta do dia', () async {
      final created = await repository.addSessions(plan.id, [
        _segment(_today, 8, 30),
        _segment(_today, 10, 20),
      ], source: SessionSource.manual);
      await settle();
      expect((await dayData(plan.id, _today))['doneMinutes'], 50);

      await repository.deleteSession(plan.id, created.first.id);
      await settle();
      expect((await dayData(plan.id, _today))['doneMinutes'], 20);
      expect(await repository.watchSessions(plan.id).first, hasLength(1));
    });

    test('finalizar dia sem documento cria com todos os campos; desfazer '
        'grava null', () async {
      final day = _today.addDays(-2);
      await repository.finalizeDay(plan.id, day);
      await settle();
      final created = await dayData(plan.id, day);
      expect(created.keys.toSet(), RulesFields.day);
      expect(created['doneMinutes'], 0);
      expect(created['finalizedAt'], isA<Timestamp>());
      expect(
        (await repository.watchDays(plan.id).first).single.isFinalized,
        isTrue,
      );

      final finalized = await agedData(child(plan.id, 'days').doc(day.toIso()));
      await repository.undoFinalizeDay(plan.id, day);
      await settle();
      final undone = await dayData(plan.id, day);
      expect(undone.containsKey('finalizedAt'), isTrue);
      expect(undone['finalizedAt'], isNull);
      expect(changedKeys(finalized, undone), {'finalizedAt', 'updatedAt'});
    });

    test('finalizar dia que já existe só troca finalizedAt', () async {
      await repository.addSessions(plan.id, [
        _segment(_today, 8, 30),
      ], source: SessionSource.focus);
      await settle();
      final before = await agedData(child(plan.id, 'days').doc(_today.toIso()));
      await repository.finalizeDay(plan.id, _today);
      await settle();
      final after = await dayData(plan.id, _today);
      expect(changedKeys(before, after), {'finalizedAt', 'updatedAt'});
      expect(after['doneMinutes'], 30);
    });
  });

  group('excluir plano', () {
    Future<Plan> planWithHistory() async {
      final plan = await newPlan(
        topics: [(name: 'Português', subjectId: null)],
      );
      await settle();
      await repository.addSessions(plan.id, [
        _segment(_today, 8, 30),
      ], source: SessionSource.focus);
      await repository.finalizeDay(plan.id, _today.addDays(-1));
      await settle();
      return plan;
    }

    Future<void> expectGone(String planId) async {
      for (final name in FirestorePlansRepository.children) {
        expect((await child(planId, name).get()).docs, isEmpty, reason: name);
      }
      expect((await plans().doc(planId).get()).exists, isFalse);
    }

    test('marca deleting, some da lista e depois apaga tudo', () async {
      final plan = await planWithHistory();
      final seenStatus = <String?>[];
      final sub = plans()
          .doc(plan.id)
          .snapshots()
          .listen((s) => seenStatus.add(s.data()?['status'] as String?));
      addTearDown(sub.cancel);

      await repository.deletePlan(plan.id);
      expect(await repository.watchPlans().first, isEmpty);
      await settle(80);

      expect(seenStatus, contains('deleting'));
      await expectGone(plan.id);
    });

    test('retoma a exclusão que ficou no meio', () async {
      final plan = await planWithHistory();
      await plans().doc(plan.id).update({'status': 'deleting'});
      expect(await repository.watchPlans().first, isEmpty);

      await repository.resumeDeletions();
      await expectGone(plan.id);
    });

    test('apaga em lotes', () async {
      final col = db.collection('lote');
      for (var i = 0; i < 5; i++) {
        await col.doc('d$i').set({'i': i});
      }
      await deleteAllDocs(db, col, batchSize: 2);
      expect((await col.get()).docs, isEmpty);
    });
  });

  group('mapas', () {
    test('documento fora do formato não quebra a lista', () {
      expect(planFromFirestore('p', {'name': 'Sem datas'}), isNull);
      expect(dayFromFirestore('ontem', {'doneMinutes': 3}), isNull);
      expect(scheduleVersionFromFirestore({'effectiveFrom': 'x'}), isNull);
    });

    test('sessão antiga com topicId vira topicIds', () {
      final session = sessionFromFirestore('p', 's', {
        'startAt': Timestamp.fromDate(DateTime(2026, 11, 11, 8)),
        'endAt': Timestamp.fromDate(DateTime(2026, 11, 11, 9)),
        'durationSeconds': 3600,
        'source': 'manual',
        'day': '2026-11-11',
        'topicId': 't1',
      })!;
      expect(session.topicIds, ['t1']);
      expect(session.minutes, 60);
    });
  });
}
