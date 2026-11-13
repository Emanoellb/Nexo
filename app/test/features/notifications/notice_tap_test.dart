import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/app/router/app_router.dart';
import 'package:nexo/app/router/routes.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/features/notifications/application/local_notices.dart';
import 'package:nexo/features/notifications/domain/local_notice.dart';
import 'package:nexo/features/tasks/application/tasks_providers.dart';
import 'package:nexo/features/tasks/domain/task.dart';

import '../../fakes/fakes.dart';

// Quarta, 04/11/2026, 10:00.
final _now = DateTime(2026, 11, 4, 10);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  SpyLocalNotices spy,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...fakeBackend(
          auth: FakeAuthRepository.signedIn(),
          flags: InMemoryLocalFlags(firstOpenDone: true),
        ),
        clockProvider.overrideWithValue(() => _now),
        localNoticesProvider.overrideWithValue(spy),
      ],
      child: const NexoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(NexoApp)));
}

String _path(ProviderContainer c) => c.read(routerProvider).state.uri.path;

void main() {
  testWidgets('toque no aviso da tarefa abre o detalhe dela', (tester) async {
    final spy = SpyLocalNotices();
    final c = await _pump(tester, spy);
    final task = await c
        .read(tasksRepositoryProvider)
        .createTask(NexoTask(id: '', title: 'Lista 3'));
    await tester.pumpAndSettle();

    spy.tapController.add(NoticeTarget.task(task.id));
    await tester.pumpAndSettle();
    expect(_path(c), AppRoutes.taskDetailOf(task.id));
  });

  testWidgets('item excluído: Início com "Isso não está mais no Nexo."', (
    tester,
  ) async {
    final spy = SpyLocalNotices();
    final c = await _pump(tester, spy);
    c.read(routerProvider).go(AppRoutes.tasks);
    await tester.pumpAndSettle();

    spy.tapController.add(NoticeTarget.plan('nao-existe'));
    await tester.pumpAndSettle();
    expect(_path(c), AppRoutes.home);
    expect(find.text('Isso não está mais no Nexo.'), findsOneWidget);
  });

  testWidgets('app aberto pelo aviso: as abas levam ao destino', (
    tester,
  ) async {
    final spy = SpyLocalNotices()..launch = NoticeTarget.home;
    final c = await _pump(tester, spy);
    expect(_path(c), AppRoutes.home);
    expect(spy.launch, isNull);
  });

  testWidgets('voltando do segundo plano, pede a permissão de novo', (
    tester,
  ) async {
    final spy = SpyLocalNotices(allowed: false);
    await _pump(tester, spy);
    expect(spy.permissionRequests, 1);

    // A janela do pedido: o app fica inativo e volta, sem ir ao fundo.
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(spy.permissionRequests, 1);

    // Segundo plano e volta: pede de novo.
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(spy.permissionRequests, 2);
  });
}
