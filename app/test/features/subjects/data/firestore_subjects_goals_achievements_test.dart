import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/firestore_access.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/goals/data/firestore_goals_repository.dart';
import 'package:nexo/features/progress/data/firestore_achievements_repository.dart';
import 'package:nexo/features/subjects/data/firestore_subjects_repository.dart';

import '../../../helpers/firestore_test_support.dart';

const _uid = 'u1';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreAccess access;

  CollectionReference<Map<String, dynamic>> col(String name) =>
      db.collection('users').doc(_uid).collection(name);

  setUp(() {
    db = FakeFirebaseFirestore();
    access = FirestoreAccess.of(db);
  });

  group('disciplinas', () {
    late FirestoreSubjectsRepository repository;
    setUp(() => repository = FirestoreSubjectsRepository(access, uid: _uid));

    test('criar: exatamente os campos das regras, nome sem espaços', () async {
      final subject = await repository.createSubject(
        name: '  Cálculo ',
        icon: 'calculator',
      );
      await settle();
      final saved = (await col('subjects').doc(subject.id).get()).data()!;
      expect(saved.keys.toSet(), RulesFields.subject);
      expect(saved['name'], 'Cálculo');
    });

    test('lista sem diferença de acento; editar e apagar', () async {
      final b = await repository.createSubject(name: 'Biologia', icon: 'atom');
      await repository.createSubject(name: 'Álgebra', icon: 'calculator');
      await settle();
      expect(
        [for (final s in await repository.watchSubjects().first) s.name],
        ['Álgebra', 'Biologia'],
      );

      await col('subjects')
          .doc(b.id)
          .update({'createdAt': oldStamp, 'updatedAt': oldStamp});
      final before = (await col('subjects').doc(b.id).get()).data()!;
      await repository.updateSubject(b.copyWith(icon: 'brain'));
      await settle();
      final after = (await col('subjects').doc(b.id).get()).data()!;
      expectValidUpdate(before, after, allowed: RulesFields.subject);

      await repository.deleteSubject(b.id);
      await settle();
      expect(await repository.watchSubjects().first, hasLength(1));
    });
  });

  group('objetivos', () {
    late FirestoreGoalsRepository repository;
    setUp(() => repository = FirestoreGoalsRepository(access, uid: _uid));

    test('criar, editar e apagar nos campos das regras', () async {
      final goal = await repository.createGoal(
        name: 'Passar no concurso',
        deadline: const LocalDate(2027, 6, 1),
      );
      await settle();
      final saved = (await col('goals').doc(goal.id).get()).data()!;
      expectValidCreate(
        saved,
        allowed: RulesFields.goal,
        required: {'name', 'createdAt', 'updatedAt'},
      );
      expect(saved['deadline'], '2027-06-01');
      expect(saved['description'], isNull);

      await col('goals')
          .doc(goal.id)
          .update({'createdAt': oldStamp, 'updatedAt': oldStamp});
      final before = (await col('goals').doc(goal.id).get()).data()!;
      await repository.updateGoal(
        goal.copyWith(description: () => 'Até junho'),
      );
      await settle();
      final after = (await col('goals').doc(goal.id).get()).data()!;
      expectValidUpdate(before, after, allowed: RulesFields.goal);
      expect(
        (await repository.watchGoals().first).single.description,
        'Até junho',
      );

      await repository.deleteGoal(goal.id);
      await settle();
      expect(await repository.watchGoals().first, isEmpty);
    });
  });

  group('conquistas', () {
    test('ganhar grava só earnedAt, uma vez só', () async {
      final repository = FirestoreAchievementsRepository(
        access,
        uid: _uid,
        clock: DateTime.now,
      );
      await repository.award('first_task');
      await settle();
      final first = (await col('achievements').doc('first_task').get()).data()!;
      expect(first.keys.toSet(), {'earnedAt'});
      expect(first['earnedAt'], isA<Timestamp>());

      await repository.award('first_task');
      await settle();
      final again = (await col('achievements').doc('first_task').get()).data()!;
      expect(again['earnedAt'], first['earnedAt']);

      final earned = await repository.watchEarned().first;
      expect(earned.single.id, 'first_task');
    });
  });
}
