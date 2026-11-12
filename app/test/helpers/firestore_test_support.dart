import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Campos das regras v0.9 (`app/firestore.rules`), para os testes dos
/// repositórios reais conferirem o que gravam sem o emulador.
abstract final class RulesFields {
  static const plan = {
    'name',
    'startDate',
    'endDate',
    'frequency',
    'dailyGoalMinutes',
    'status',
    'pauses',
    'endedOn',
    'goalId',
    'studyTime',
    'reminderBefore',
    'createdAt',
    'updatedAt',
  };
  static const planRequired = {
    'name',
    'startDate',
    'endDate',
    'frequency',
    'dailyGoalMinutes',
    'status',
    'createdAt',
    'updatedAt',
  };

  /// Exatamente estes (hasOnly + hasAll).
  static const version = {
    'effectiveFrom',
    'frequency',
    'dailyGoalMinutes',
    'createdAt',
  };
  static const topic = {'name', 'subjectId', 'createdAt', 'updatedAt'};
  static const session = {
    'startAt',
    'endAt',
    'durationSeconds',
    'source',
    'topicIds',
    'note',
    'day',
    'createdAt',
    'updatedAt',
  };
  static const sessionRequired = {
    'startAt',
    'endAt',
    'durationSeconds',
    'source',
    'day',
    'createdAt',
    'updatedAt',
  };

  /// Exatamente estes no create (validCreate(dayFields(), dayFields())).
  static const day = {'doneMinutes', 'finalizedAt', 'createdAt', 'updatedAt'};
  static const task = {
    'title',
    'subjectId',
    'dueAt',
    'priority',
    'completed',
    'completedAt',
    'remindersMinutesBefore',
    'deliveryStatus',
    'createdAt',
    'updatedAt',
  };
  static const taskRequired = {
    'title',
    'priority',
    'completed',
    'completedAt',
    'createdAt',
    'updatedAt',
  };

  /// Exatamente estes no create.
  static const subject = {'name', 'icon', 'createdAt', 'updatedAt'};
  static const goal = {
    'name',
    'description',
    'deadline',
    'createdAt',
    'updatedAt',
  };
}

/// Um carimbo antigo, para ver o `updatedAt` mudar.
final oldStamp = Timestamp(1000, 0);

/// Envelhece o `updatedAt` do documento e devolve os dados: assim a troca
/// do carimbo aparece mesmo quando duas gravações caem no mesmo instante (o
/// relógio do Windows anda em passos de cerca de 1 ms).
Future<Map<String, dynamic>> agedData(
  DocumentReference<Map<String, dynamic>> ref,
) async {
  await ref.update({'updatedAt': oldStamp});
  return (await ref.get()).data()!;
}

/// Dá tempo de as gravações que não esperam o servidor (e a limpeza em
/// segundo plano) chegarem ao banco em memória.
Future<void> settle([int turns = 30]) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Chaves que mudaram entre dois estados de um documento.
Set<String> changedKeys(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) => {
  ...before.keys,
  ...after.keys,
}.where((k) => '${before[k]}' != '${after[k]}').toSet();

/// Create válido: só campos permitidos, todos os obrigatórios e os
/// carimbos.
void expectValidCreate(
  Map<String, dynamic> data, {
  required Set<String> allowed,
  required Set<String> required,
  bool stamps = true,
}) {
  expect(
    data.keys.toSet().difference(allowed),
    isEmpty,
    reason: 'fora das regras',
  );
  expect(data.keys.toSet().containsAll(required), isTrue, reason: 'faltando');
  if (stamps) {
    expect(data['createdAt'], isA<Timestamp>());
    expect(data['updatedAt'], isA<Timestamp>());
  }
}

/// Update válido: só campos permitidos, sem trocar o `createdAt` e com o
/// `updatedAt` novo.
void expectValidUpdate(
  Map<String, dynamic> before,
  Map<String, dynamic> after, {
  required Set<String> allowed,
}) {
  final changed = changedKeys(before, after);
  expect(changed.difference(allowed), isEmpty, reason: 'fora das regras');
  expect(changed, isNot(contains('createdAt')));
  expect(changed, contains('updatedAt'));
}
