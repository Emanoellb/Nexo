import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/features/profile/presentation/profile_page.dart';
import 'package:nexo/features/calendar/presentation/agenda_page.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/features/auth/domain/auth_user.dart';
import 'package:nexo/features/notifications/domain/nexo_notification.dart';
import 'package:nexo/features/home/presentation/home_page.dart';
import 'package:nexo/features/plans/presentation/plans_page.dart';
import 'package:nexo/features/tasks/presentation/tasks_page.dart';
import 'package:nexo/core/ui/ui.dart';

import '../fakes/fakes.dart';

/// App logado com a conta pronta e, se pedido, avisos de exemplo.
Future<FakeNotificationsRepository> _pumpReady(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final now = DateTime(2026, 11, 4, 12);
  final notifications = FakeNotificationsRepository(clock: () => now);
  addTearDown(notifications.dispose);
  notifications.add(
    kind: NotificationKind.overdue,
    title: 'Tarefa atrasada',
    body: 'Resumo do capítulo 2 · venceu ontem, 23:59',
    createdAt: now.subtract(const Duration(hours: 5)),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...fakeBackend(
          auth: FakeAuthRepository.signedIn(),
          profiles: FakeUserProfileRepository.prototype(),
          notifications: notifications,
        ),
        clockProvider.overrideWithValue(() => now),
      ],
      child: const NexoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return notifications;
}

/// Aperta o voltar do Android (mensagem `popRoute` da plataforma).
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('usuário pronto abre no Início e navega pelas abas', (
    tester,
  ) async {
    await _pumpReady(tester);
    expect(find.byType(HomePage), findsOneWidget);
    // Saudação só no Início (perfil "Ana" na conta pronta).
    expect(find.text('Olá, Ana'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.target));
    await tester.pumpAndSettle();
    expect(find.byType(PlansPage), findsOneWidget);
    expect(find.text('Seus planos aparecem aqui'), findsOneWidget);
    expect(find.textContaining('Olá'), findsNothing);

    // "Calendário" virou "Agenda" no texto; a rota é a mesma.
    await tester.tap(find.byIcon(LucideIcons.calendarDays));
    await tester.pumpAndSettle();
    expect(find.byType(AgendaPage), findsOneWidget);
    expect(find.text('Semana'), findsOneWidget);
  });

  testWidgets('avatar com as iniciais abre o Perfil, e a seta volta', (
    tester,
  ) async {
    await _pumpReady(tester);
    // Perfil "Ana" na conta pronta.
    expect(find.text('A'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('sino: abrir não marca lido; tocar marca e vai à aba', (
    tester,
  ) async {
    final notifications = await _pumpReady(tester);
    expect(find.bySemanticsLabel('Notificações, 1 não lida'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.bell));
    await tester.pumpAndSettle();
    expect(find.text('Tarefa atrasada'), findsOneWidget);
    expect(
      (await notifications.watchNotifications().first).single.read,
      isFalse,
    );

    await tester.tap(find.text('Tarefa atrasada'));
    await tester.pumpAndSettle();
    expect(
      (await notifications.watchNotifications().first).single.read,
      isTrue,
    );
    expect(find.byType(TasksPage), findsOneWidget);
    expect(find.bySemanticsLabel('Notificações'), findsOneWidget);
  });

  testWidgets('painel fecha com toque fora', (tester) async {
    await _pumpReady(tester);
    await tester.tap(find.byIcon(LucideIcons.bell));
    await tester.pumpAndSettle();
    expect(find.text('Últimos 30 dias'), findsOneWidget);
    await tester.tapAt(const Offset(40, 600));
    await tester.pumpAndSettle();
    expect(find.text('Últimos 30 dias'), findsNothing);
  });

  testWidgets('o "+" está em todas as abas; "Nova tarefa" abre a tela', (
    tester,
  ) async {
    await _pumpReady(tester);
    for (final icon in [LucideIcons.listTodo, LucideIcons.house]) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Criar'), findsOneWidget);
    }
    await tester.tap(find.byType(NexoFab));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova tarefa'));
    await tester.pumpAndSettle();
    // Nova tarefa em tela cheia, por cima das abas, com o X.
    expect(find.text('Criar tarefa'), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('sem login vai ao Login; ao entrar, vai ao Início', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...fakeBackend(auth: auth)],
        child: const NexoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Entre na sua conta'), findsOneWidget);

    auth.setUser(FakeAuthRepository.prototypeUser);
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('e-mail não verificado vai à tela de verificação', (
    tester,
  ) async {
    final auth = FakeAuthRepository(
      initialUser: const AuthUser(
        uid: 'u2',
        emailVerified: false,
        email: 'nova.conta@email.com',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...fakeBackend(auth: auth)],
        child: const NexoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirme seu e-mail'), findsOneWidget);
  });

  testWidgets('Google sem perfil vai ao primeiro acesso; tutorial depois', (
    tester,
  ) async {
    const user = AuthUser(
      uid: 'g1',
      emailVerified: true,
      signedInWithGoogle: true,
      email: FakeAuthRepository.googleEmail,
    );
    final auth = FakeAuthRepository(initialUser: user);
    final profiles = FakeUserProfileRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...fakeBackend(auth: auth, profiles: profiles)],
        child: const NexoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Falta pouco'), findsOneWidget);

    profiles.setProfile(user.uid, const UserProfile(displayName: 'Ana'));
    await tester.pumpAndSettle();
    expect(find.text('Objetivo e plano'), findsOneWidget);
  });

  testWidgets('voltar fora do Início vai ao Início; no Início pergunta', (
    tester,
  ) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pumpReady(tester);

    // Planos (raiz da aba): voltar leva ao Início.
    await tester.tap(find.byIcon(LucideIcons.target));
    await tester.pumpAndSettle();
    await _systemBack(tester);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Olá, Ana'), findsOneWidget);

    // No Início: pergunta; "Cancelar" fica no app.
    await _systemBack(tester);
    expect(find.text('Deseja sair do app?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Deseja sair do app?'), findsNothing);
    expect(calls, isNot(contains('SystemNavigator.pop')));

    // "Sair" fecha o app.
    await _systemBack(tester);
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(calls, contains('SystemNavigator.pop'));
  });
}
