import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/features/tasks/domain/task_rules.dart';

void main() {
  group('situação da entrega', () {
    test('valores persistidos e textos', () {
      expect(
        DeliveryStatus.fromValue('awaitingGrade'),
        DeliveryStatus.awaitingGrade,
      );
      expect(DeliveryStatus.fromValue(null), isNull);
      expect(DeliveryStatus.delivered.label, 'Entregue');
    });

    test('coerência com a conclusão (como nas regras)', () {
      for (final s in DeliveryStatus.values) {
        expect(
          isDeliveryStatusCoherent(completed: false, status: s),
          s.isPending,
          reason: 'pendente com ${s.value}',
        );
        expect(
          isDeliveryStatusCoherent(completed: true, status: s),
          !s.isPending,
          reason: 'concluída com ${s.value}',
        );
      }
      expect(isDeliveryStatusCoherent(completed: true, status: null), isTrue);
    });

    test(
      'concluir troca para "Entregue"; reabrir volta para "Em andamento"',
      () {
        expect(
          deliveryStatusOnComplete(DeliveryStatus.notStarted),
          DeliveryStatus.delivered,
        );
        expect(
          deliveryStatusOnComplete(DeliveryStatus.awaitingGrade),
          DeliveryStatus.awaitingGrade,
        );
        expect(
          deliveryStatusOnReopen(DeliveryStatus.delivered),
          DeliveryStatus.inProgress,
        );
        expect(
          deliveryStatusOnReopen(DeliveryStatus.notStarted),
          DeliveryStatus.notStarted,
        );
        expect(deliveryStatusOnComplete(null), isNull);
        expect(deliveryStatusOnReopen(null), isNull);
      },
    );

    test('o resultado de concluir e de reabrir é sempre coerente', () {
      for (final s in [...DeliveryStatus.values, null]) {
        expect(
          isDeliveryStatusCoherent(
            completed: true,
            status: deliveryStatusOnComplete(s),
          ),
          isTrue,
        );
        expect(
          isDeliveryStatusCoherent(
            completed: false,
            status: deliveryStatusOnReopen(s),
          ),
          isTrue,
        );
      }
    });
  });

  group('atrasada', () {
    final now = DateTime(2026, 10, 26, 12);

    test('pendente com prazo vencido', () {
      expect(
        isTaskOverdue(
          completed: false,
          dueAt: DateTime(2026, 10, 26, 11),
          now: now,
        ),
        isTrue,
      );
    });

    test('concluída, sem prazo ou com prazo futuro não está atrasada', () {
      expect(
        isTaskOverdue(completed: true, dueAt: DateTime(2026, 10, 1), now: now),
        isFalse,
      );
      expect(isTaskOverdue(completed: false, dueAt: null, now: now), isFalse);
      expect(
        isTaskOverdue(
          completed: false,
          dueAt: DateTime(2026, 10, 27),
          now: now,
        ),
        isFalse,
      );
    });
  });

  test('pontos da tarefa: +1 ao concluir, −1 ao reabrir', () {
    expect(taskPointsDelta(wasCompleted: false, isCompleted: true), 1);
    expect(taskPointsDelta(wasCompleted: true, isCompleted: false), -1);
    expect(taskPointsDelta(wasCompleted: true, isCompleted: true), 0);
  });

  test('aviso de entrega: só com prazo e entre 1 min e 30 dias', () {
    final due = DateTime(2026, 11, 1);
    expect(
      TaskReminder.isValid(minutesBefore: TaskReminder.oneDay, dueAt: due),
      isTrue,
    );
    expect(TaskReminder.isValid(minutesBefore: 60, dueAt: null), isFalse);
    expect(TaskReminder.isValid(minutesBefore: 0, dueAt: due), isFalse);
    expect(TaskReminder.isValid(minutesBefore: 43201, dueAt: due), isFalse);
    expect(TaskReminder.isValid(minutesBefore: null, dueAt: null), isTrue);
  });
}
