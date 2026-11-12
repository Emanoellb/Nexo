import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/features/tasks/domain/task.dart';
import 'package:nexo/features/tasks/domain/task_rules.dart';

import '../../fakes/fakes.dart';

final _now = DateTime(2026, 10, 26, 12);

void main() {
  group('NexoTask: limites das regras', () {
    test('título de 1 a 200 caracteres', () {
      expect(() => NexoTask(id: 't', title: ''), throwsArgumentError);
      expect(() => NexoTask(id: 't', title: 'x' * 201), throwsArgumentError);
    });

    test('aviso de entrega só com prazo', () {
      expect(
        () => NexoTask(
          id: 't',
          title: 'Lista 3',
          remindersMinutesBefore: const [60],
        ),
        throwsArgumentError,
      );
    });

    test('tirar o prazo esvazia os avisos no mesmo gravar', () {
      final task = NexoTask(
        id: 't',
        title: 'Lista 3',
        dueAt: _now,
        remindersMinutesBefore: TaskReminder.suggested,
      );
      expect(task.copyWith(dueAt: () => null).remindersMinutesBefore, isEmpty);
      expect(
        task.copyWith(dueAt: () => _now).remindersMinutesBefore,
        TaskReminder.suggested,
      );
    });

    test('situação incoerente com a conclusão é recusada', () {
      expect(
        () => NexoTask(
          id: 't',
          title: 'Lista 3',
          completed: true,
          deliveryStatus: DeliveryStatus.inProgress,
        ),
        throwsArgumentError,
      );
    });

    test('mapa com os valores do contrato', () {
      final map = NexoTask(
        id: 't',
        title: 'Lista 3',
        priority: TaskPriority.high,
        dueAt: _now,
        remindersMinutesBefore: const [TaskReminder.oneHour, 1440],
        deliveryStatus: DeliveryStatus.notStarted,
      ).toMap();
      expect(map['priority'], 'high');
      expect(map['deliveryStatus'], 'notStarted');
      expect(map['remindersMinutesBefore'], [60, 1440]);
      expect(map.containsKey('reminderMinutesBefore'), isFalse);
      expect(map['completed'], isFalse);
    });
  });

  group('FakeTasksRepository', () {
    late FakeTasksRepository repo;

    setUp(() {
      repo = FakeTasksRepository(clock: () => _now);
      addTearDown(repo.dispose);
    });

    test(
      'pendentes por prazo, sem prazo no fim, concluídas por último',
      () async {
        Future<NexoTask> add(String title, {DateTime? due}) =>
            repo.createTask(NexoTask(id: '', title: title, dueAt: due));
        await add('Sem prazo');
        await add('Amanhã', due: _now.add(const Duration(days: 1)));
        await add('Hoje', due: _now.add(const Duration(hours: 2)));
        final feita = await add('Feita', due: _now);
        await repo.setCompleted(feita.id, true);

        final titles = (await repo.watchTasks().first).map((t) => t.title);
        expect(titles, ['Hoje', 'Amanhã', 'Sem prazo', 'Feita']);
      },
    );

    test(
      'concluir: +1 ponto e "Entregue"; reabrir: −1 e "Em andamento"',
      () async {
        final task = await repo.createTask(
          NexoTask(
            id: '',
            title: 'Lista 3',
            dueAt: _now,
            deliveryStatus: DeliveryStatus.notStarted,
          ),
        );
        expect(await repo.setCompleted(task.id, true), 1);
        var stored = (await repo.watchTasks().first).single;
        expect(stored.deliveryStatus, DeliveryStatus.delivered);
        expect(stored.completedAt, _now);

        expect(await repo.setCompleted(task.id, false), -1);
        stored = (await repo.watchTasks().first).single;
        expect(stored.deliveryStatus, DeliveryStatus.inProgress);
        expect(stored.completedAt, isNull);

        expect(await repo.setCompleted(task.id, false), 0);
      },
    );

    test('apagar tarefa concluída desconta 1 ponto; pendente, 0', () async {
      final feita = await repo.createTask(
        NexoTask(id: '', title: 'Lista 3', dueAt: _now),
      );
      final pendente = await repo.createTask(
        NexoTask(id: '', title: 'Resumo', dueAt: _now),
      );
      await repo.setCompleted(feita.id, true);

      expect(await repo.deleteTask(feita.id), -1);
      expect(await repo.deleteTask(pendente.id), 0);
      expect(await repo.watchTasks().first, isEmpty);
    });
  });
}
