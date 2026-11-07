import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/data/fake_auth_repository.dart';
import 'package:nexo/features/auth/domain/auth_user.dart';
import 'package:nexo/features/tasks/application/task_actions.dart';
import 'package:nexo/features/tasks/application/tasks_providers.dart';
import 'package:nexo/features/tasks/domain/task.dart';

const _otherUser = AuthUser(
  uid: 'outra-conta',
  emailVerified: true,
  email: 'bruno.lima@email.com',
  displayName: 'Bruno',
);

Future<(ProviderContainer, FakeAuthRepository)> _container() async {
  final auth = FakeAuthRepository.signedIn();
  final c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 4, 10)),
      authRepositoryProvider.overrideWithValue(auth),
    ],
  );
  addTearDown(c.dispose);
  c
    ..listen(authStateProvider, (_, _) {})
    ..listen(visibleTasksProvider, (_, _) {});
  await c.read(authStateProvider.future);
  return (c, auth);
}

Future<NexoTask> _create(ProviderContainer c, String title) =>
    c.read(tasksRepositoryProvider).createTask(NexoTask(id: '', title: title));

Future<List<String>> _titles(ProviderContainer c) async => [
  for (final t in await c.read(tasksRepositoryProvider).watchTasks().first)
    t.title,
];

void main() {
  test('pendente some das listas; "Desfazer" devolve; o fim apaga', () async {
    final (c, _) = await _container();
    final task = await _create(c, 'Lista de exercícios 3');
    await pumpEventQueue();
    final deletion = c.read(taskDeletionProvider);

    final receipt = deletion.begin(task.id);
    await pumpEventQueue();
    expect(c.read(visibleTasksProvider).value, isEmpty);
    deletion.undo(receipt);
    await pumpEventQueue();
    expect(c.read(visibleTasksProvider).value, hasLength(1));

    await deletion.finish(deletion.begin(task.id));
    expect(await _titles(c), isEmpty);
    expect(c.read(pendingTaskDeletionsProvider), isEmpty);
  });

  test('trocar de conta antes do fim não apaga nada na conta nova', () async {
    final (c, auth) = await _container();
    // Conta A: começa a excluir a "tarefa-1".
    final a = await _create(c, 'Tarefa da Ana');
    final receipt = c.read(taskDeletionProvider).begin(a.id);

    // Conta B: os ids do fake recomeçam, então ela também tem "tarefa-1".
    auth.setUser(_otherUser);
    await pumpEventQueue();
    final b = await _create(c, 'Tarefa do Bruno');
    expect(b.id, a.id);
    // O pendente da conta A não esconde nada na B.
    expect(c.read(pendingTaskDeletionsProvider), isEmpty);

    // O aviso da conta A some agora: nada é apagado na B.
    await c.read(taskDeletionProvider).finish(receipt);
    expect(await _titles(c), ['Tarefa do Bruno']);
  });
}
