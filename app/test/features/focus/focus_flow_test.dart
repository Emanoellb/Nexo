import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/app/router/app_router.dart';
import 'package:nexo/app/router/routes.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/data/local_flags.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/core/ui/ui.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/data/fake_auth_repository.dart';
import 'package:nexo/features/focus/application/focus_controller.dart';
import 'package:nexo/features/focus/application/focus_system.dart';
import 'package:nexo/features/focus/domain/active_focus.dart';
import 'package:nexo/features/focus/domain/focus_session.dart';
import 'package:nexo/features/focus/domain/session_split.dart';
import 'package:nexo/features/focus/presentation/focus_page.dart';
import 'package:nexo/features/plans/application/plans_providers.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/plans/presentation/plan_detail_page.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';

// Quarta, 04/11/2026, 10:00.
final _start = DateTime(2026, 11, 4, 10);
const _today = LocalDate(2026, 11, 4);

/// O relógio anda pelos testes.
var _now = _start;

void _advance(Duration d) => _now = _now.add(d);

/// Sistema falso: registra o que o foco pediu ao Android.
class _FakeSystem implements FocusSystem {
  bool granted = false;
  bool dndOn = false;
  int permissionRequests = 0;
  final dndCalls = <bool>[];
  final shown = <(ActiveFocus, String)>[];
  int cleared = 0;
  final taps = StreamController<void>.broadcast();

  @override
  bool get supportsDnd => true;

  @override
  bool get dndOnSinceLaunch => dndOn;

  @override
  Future<bool> dndAccessGranted() async => granted;

  /// A pessoa dá o acesso na tela do sistema e volta.
  @override
  Future<bool> openDndSettings() async => granted = true;

  @override
  Future<bool> setDnd({required bool on}) async {
    dndCalls.add(on);
    dndOn = on && granted;
    return granted;
  }

  /// A resposta à permissão (completa na hora, se `null`).
  Completer<void>? permissionAnswer;

  @override
  Future<void> requestNotificationPermission() async {
    permissionRequests++;
    await permissionAnswer?.future;
  }

  @override
  Future<void> showOngoing(ActiveFocus focus, {required String detail}) async =>
      shown.add((focus, detail));

  @override
  Future<void> clearOngoing() async => cleared++;

  @override
  Stream<void> get openFocusRequests => taps.stream;

  @override
  bool takeLaunchFromNotification() => false;
}

/// App logado, com o plano principal "Concurso Banco Horizonte" (45 min por
/// dia, [doneToday] já feitos hoje) e o tópico "Juros simples".
Future<(ProviderContainer, Plan)> _pump(
  WidgetTester tester, {
  bool dark = false,
  int doneToday = 0,
  double textScale = 1,
  InMemoryLocalFlags? flags,
  FocusSystem? system,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
        clockProvider.overrideWithValue(() => _now),
        if (system != null) focusSystemProvider.overrideWithValue(system),
        localFlagsProvider.overrideWithValue(
          flags ??
              InMemoryLocalFlags(
                firstOpenDone: true,
                themePreference: dark ? 'dark' : 'light',
              ),
        ),
      ],
      child: const NexoApp(),
    ),
  );
  await tester.pumpAndSettle();
  final c = ProviderScope.containerOf(tester.element(find.byType(NexoApp)));
  final plans = c.read(plansRepositoryProvider);
  final plan = await plans.createPlan(
    Plan(
      id: '',
      name: 'Concurso Banco Horizonte',
      startDate: _today.addDays(-10),
      endDate: _today.addDays(100),
      frequency: const DailyFrequency(),
      dailyGoalMinutes: 45,
    ),
  );
  await plans.addTopic(plan.id, 'Juros simples');
  await c
      .read(userProfileRepositoryProvider)
      .setPrimaryPlan(FakeAuthRepository.prototypeUser.uid, plan.id);
  if (doneToday > 0) {
    final start = DateTime(2026, 11, 4, 8);
    await plans.addSessions(
      plan.id,
      splitSessionByDay([
        ActiveInterval(start, start.add(Duration(minutes: doneToday))),
      ]),
      source: SessionSource.focus,
    );
  }
  await tester.pumpAndSettle();
  return (c, plan);
}

Future<List<FocusSession>> _sessions(ProviderContainer c, String planId) =>
    c.read(plansRepositoryProvider).watchSessions(planId).first;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.widgetWithText(NexoButton, label);

/// Passa [d] no relógio e deixa o cronômetro atualizar.
Future<void> _wait(WidgetTester tester, Duration d) async {
  _advance(d);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// Abre o seletor de hora do campo [label], passa para a digitação e
/// confirma [hour]:[minute].
Future<void> _typeTime(
  WidgetTester tester,
  String label,
  int hour,
  int minute,
) async {
  await _tap(tester, find.widgetWithText(NexoSelectField, label));
  await _tap(tester, find.byIcon(Icons.keyboard_outlined));
  final fields = find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), '$hour'.padLeft(2, '0'));
  await tester.enterText(fields.at(1), '$minute'.padLeft(2, '0'));
  await _tap(tester, find.text('OK'));
}

Future<void> _openFocus(WidgetTester tester) async {
  await _tap(tester, _button('Focar'));
  expect(find.byType(FocusPage), findsOneWidget);
}

void main() {
  setUp(() => _now = _start);

  testWidgets('Focar começa na hora; pausar e retomar descontam a pausa', (
    tester,
  ) async {
    await _pump(tester);
    await _openFocus(tester);
    expect(find.text('Sessão de foco'), findsOneWidget);
    expect(find.text('Concurso Banco Horizonte'), findsOneWidget);
    expect(find.text('Hoje: 0 min de 45 min'), findsOneWidget);
    // Sem as partes nativas, o "Não perturbe" não aparece.
    expect(find.text('Não perturbe'), findsNothing);

    await _wait(tester, const Duration(minutes: 10));
    expect(find.text('00:10:00'), findsOneWidget);
    expect(find.text('Hoje: 10 min de 45 min'), findsOneWidget);

    await _tap(tester, _button('Pausar'));
    await _wait(tester, const Duration(minutes: 3));
    expect(find.text('Pausado há 3 min'), findsOneWidget);
    expect(find.text('00:10:00'), findsOneWidget);
    expect(_button('Retomar'), findsOneWidget);

    await _tap(tester, _button('Retomar'));
    await _wait(tester, const Duration(minutes: 2));
    expect(find.text('00:12:00'), findsOneWidget);
  });

  testWidgets('sessão curta não é salva; Desfazer volta ao foco', (
    tester,
  ) async {
    final (c, plan) = await _pump(tester);
    await _openFocus(tester);
    await _wait(tester, const Duration(seconds: 40));
    await _tap(tester, _button('Encerrar'));
    expect(find.byType(FocusPage), findsNothing);
    expect(find.text('Sessão muito curta para salvar.'), findsOneWidget);
    expect(c.read(activeFocusProvider), isNull);
    expect(await _sessions(c, plan.id), isEmpty);

    await _tap(tester, find.text('Desfazer'));
    expect(c.read(activeFocusProvider)?.planId, plan.id);
  });

  testWidgets('salvar com tópico: meta do dia batida e Desfazer apaga', (
    tester,
  ) async {
    final (c, plan) = await _pump(tester, doneToday: 30);
    await _openFocus(tester);
    await _tap(tester, find.text('Adicionar tópico'));
    await _tap(tester, find.text('Juros simples'));
    await _wait(tester, const Duration(minutes: 20));

    await _tap(tester, _button('Encerrar'));
    expect(find.text('Encerrar sessão'), findsOneWidget);
    expect(find.text('20 min'), findsWidgets);
    await _tap(tester, _button('Salvar sessão'));
    expect(
      find.text('Sessão salva · +20 min. Meta do dia batida!'),
      findsOneWidget,
    );
    final sessions = await _sessions(c, plan.id);
    expect(sessions, hasLength(2));
    final saved = sessions.firstWhere((s) => s.startAt == _start);
    expect(saved.topicIds, hasLength(1));
    expect(saved.minutes, 20);

    await _tap(tester, find.text('Desfazer'));
    expect(await _sessions(c, plan.id), hasLength(1));
  });

  testWidgets('descartar não salva e Desfazer volta ao foco', (tester) async {
    final (c, plan) = await _pump(tester);
    await _openFocus(tester);
    await _wait(tester, const Duration(minutes: 5));
    await _tap(tester, _button('Encerrar'));
    await _tap(tester, _button('Descartar sessão'));
    expect(find.text('Sessão descartada.'), findsOneWidget);
    expect(await _sessions(c, plan.id), isEmpty);
    await _tap(tester, find.text('Desfazer'));
    expect(c.read(activeFocusProvider), isNotNull);
  });

  testWidgets('minimizar e o voltar mostram a Barra do foco; tocar reabre', (
    tester,
  ) async {
    final (c, _) = await _pump(tester);
    await _openFocus(tester);
    await _wait(tester, const Duration(minutes: 24));

    // O voltar do aparelho minimiza, não encerra.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(FocusPage), findsNothing);
    expect(c.read(activeFocusProvider), isNotNull);
    expect(find.byType(NexoFocusBar), findsOneWidget);
    expect(find.text('Foco · 00:24:00'), findsOneWidget);
    // O cartão do plano vira "Em foco agora".
    expect(find.text('Em foco agora · 00:24:00'), findsOneWidget);
    expect(_button('Voltar ao foco'), findsOneWidget);

    // Pausar pela barra; a barra fica em todas as abas.
    await _tap(tester, find.byTooltip('Pausar'));
    expect(find.text('Pausado · 00:24:00'), findsOneWidget);
    await _tap(tester, find.text('Tarefas').last);
    expect(find.byType(NexoFocusBar), findsOneWidget);

    // Tocar reabre o foco; a seta para baixo minimiza de novo.
    await _tap(tester, find.text('Pausado · 00:24:00'));
    expect(find.byType(FocusPage), findsOneWidget);
    expect(_button('Retomar'), findsOneWidget);
    await _tap(tester, find.byTooltip('Minimizar'));
    expect(find.byType(FocusPage), findsNothing);
    expect(find.byType(NexoFocusBar), findsOneWidget);
  });

  testWidgets('cruzou a meia-noite: a sessão vira duas, uma em cada dia', (
    tester,
  ) async {
    _now = DateTime(2026, 11, 3, 23, 40);
    final (c, plan) = await _pump(tester);
    await c.read(activeFocusProvider.notifier).start(plan.id);
    _now = DateTime(2026, 11, 4, 0, 30);
    final result = await c.read(focusActionsProvider).finish(topicIds: []);
    expect(result, isA<FocusSaved>());
    final days = (result as FocusSaved).sessions.map((s) => s.day).toList();
    expect(days, [const LocalDate(2026, 11, 3), const LocalDate(2026, 11, 4)]);
    expect(result.sessions.map((s) => s.minutes), [20, 30]);
  });

  testWidgets('Registrar horas: erros, salvar e Editar sessão com Excluir', (
    tester,
  ) async {
    final (c, plan) = await _pump(tester);
    final router = c.read(routerProvider);
    router.push(AppRoutes.logHoursFor(plan.id));
    await tester.pumpAndSettle();
    expect(find.text('Registrar horas'), findsOneWidget);
    expect(find.text('Hoje, qua 4/11'), findsOneWidget);

    // Sem início e fim: o erro aparece no Fim.
    await _tap(tester, _button('Salvar'));
    expect(find.text('Escolha o início e o fim.'), findsOneWidget);

    // Início 09:00 e fim 08:00: o fim precisa ser depois.
    await _typeTime(tester, 'Início', 9, 0);
    await _typeTime(tester, 'Fim', 8, 0);
    expect(find.text('O fim precisa ser depois do início.'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);

    // Início 08:00 e fim 09:30: 1h 30min.
    await _typeTime(tester, 'Início', 8, 0);
    await _typeTime(tester, 'Fim', 9, 30);
    expect(find.text('O fim precisa ser depois do início.'), findsNothing);
    expect(find.text('1h 30min'), findsOneWidget);
    await _tap(tester, _button('Salvar'));
    expect(find.text('Horas registradas.'), findsOneWidget);
    final sessions = await _sessions(c, plan.id);
    expect(sessions.single.source, SessionSource.manual);
    expect(sessions.single.minutes, 90);

    // Editar sessão: Excluir com Desfazer.
    router.push(AppRoutes.editSessionOf(plan.id, sessions.single.id));
    await tester.pumpAndSettle();
    expect(find.text('Editar sessão'), findsOneWidget);
    expect(find.text('Registro manual · hoje'), findsOneWidget);
    await _tap(tester, _button('Excluir sessão'));
    expect(find.text('Sessão excluída.'), findsOneWidget);
    expect(await _sessions(c, plan.id), isEmpty);
    await _tap(tester, find.text('Desfazer'));
    expect(await _sessions(c, plan.id), hasLength(1));
  });

  testWidgets('Editar sessão só na nota mantém horários e duração líquida', (
    tester,
  ) async {
    final (c, plan) = await _pump(tester);
    // Foco de 08:00:30 a 09:00:30 com 20 min de pausa: 40 min líquidos.
    await c.read(plansRepositoryProvider).addSessions(plan.id, [
      DaySegment(
        day: _today,
        startAt: DateTime(2026, 11, 4, 8, 0, 30),
        endAt: DateTime(2026, 11, 4, 9, 0, 30),
        durationSeconds: 40 * 60,
      ),
    ], source: SessionSource.focus);
    final before = (await _sessions(c, plan.id)).single;
    c.read(routerProvider).push(AppRoutes.editSessionOf(plan.id, before.id));
    await tester.pumpAndSettle();
    expect(find.text('Sessão de foco · hoje'), findsOneWidget);
    expect(find.text('40 min'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(NexoTextField, 'Nota'),
      'Lista 3',
    );
    await _tap(tester, _button('Salvar'));
    expect(find.text('Alterações salvas.'), findsOneWidget);
    final after = (await _sessions(c, plan.id)).single;
    expect(after.note, 'Lista 3');
    expect(after.startAt, before.startAt);
    expect(after.endAt, before.endAt);
    expect(after.durationSeconds, 40 * 60);
  });

  testWidgets('notificação fixa: pede a permissão, mostra, pausa e sai', (
    tester,
  ) async {
    final system = _FakeSystem();
    await _pump(tester, system: system);
    await _openFocus(tester);
    expect(system.permissionRequests, 1);
    expect(system.shown.last.$2, 'Concurso Banco Horizonte');
    expect(system.shown.last.$1.isPaused, isFalse);

    await _tap(tester, find.text('Adicionar tópico'));
    await _tap(tester, find.text('Juros simples'));
    expect(system.shown.last.$2, 'Concurso Banco Horizonte · Juros simples');
    await _tap(tester, _button('Pausar'));
    expect(system.shown.last.$1.isPaused, isTrue);

    // Tocar na notificação com o foco minimizado reabre o foco.
    await _tap(tester, find.byTooltip('Minimizar'));
    system.taps.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(FocusPage), findsOneWidget);

    await _wait(tester, const Duration(seconds: 10));
    await _tap(tester, _button('Encerrar'));
    expect(system.cleared, 1);
  });

  testWidgets('"Não perturbe": painel com 3 opções, acesso e desligar ao '
      'encerrar', (tester) async {
    final system = _FakeSystem();
    final (c, _) = await _pump(tester, system: system);
    await _openFocus(tester);
    expect(find.text('Não perturbe'), findsOneWidget);

    // "Apenas esta vez": liga agora e pergunta de novo da próxima vez.
    await _tap(tester, find.text('Não perturbe'));
    expect(find.text('Silenciar o celular no foco?'), findsOneWidget);
    expect(
      find.text(
        'O “Não perturbe” é desligado quando você encerra o foco ou reabre '
        'o app.',
      ),
      findsOneWidget,
    );
    await _tap(tester, _button('Apenas esta vez'));
    expect(system.dndCalls, [true]);
    expect(c.read(activeFocusProvider)!.dnd, isTrue);

    await _tap(tester, find.text('Não perturbe'));
    expect(system.dndCalls, [true, false]);
    expect(c.read(activeFocusProvider)!.dnd, isFalse);

    // "Não permitir": continua desligado.
    await _tap(tester, find.text('Não perturbe'));
    await _tap(tester, _button('Não permitir'));
    expect(system.dndCalls, [true, false]);

    // "Permitir durante o uso do app": não pergunta mais.
    await _tap(tester, find.text('Não perturbe'));
    await _tap(tester, _button('Permitir durante o uso do app'));
    await _tap(tester, find.text('Não perturbe'));
    await _tap(tester, find.text('Não perturbe'));
    expect(find.text('Silenciar o celular no foco?'), findsNothing);
    expect(system.dndCalls, [true, false, true, false, true]);

    // Encerrar (sessão curta) desliga o modo; o Desfazer volta sem ele.
    await _tap(tester, _button('Encerrar'));
    expect(system.dndCalls.last, isFalse);
    expect(system.dndOn, isFalse);
    await _tap(tester, find.text('Desfazer'));
    expect(c.read(activeFocusProvider)!.dnd, isFalse);
  });

  testWidgets('reabrir o app com o "Não perturbe" de antes: vem desligado', (
    tester,
  ) async {
    final flags = InMemoryLocalFlags(
      firstOpenDone: true,
      themePreference: 'light',
    );
    flags.activeFocusByUid[FakeAuthRepository.prototypeUser.uid] = ActiveFocus(
      planId: 'p1',
      startedAt: _start,
      dnd: true,
    ).toJson();
    final (c, _) = await _pump(tester, flags: flags, system: _FakeSystem());
    final focus = c.read(activeFocusProvider)!;
    expect(focus.dnd, isFalse);
    expect(
      ActiveFocus.fromJson(
        flags.activeFocus(FakeAuthRepository.prototypeUser.uid),
      )!.dnd,
      isFalse,
    );
  });

  testWidgets('o tempo só começa depois da resposta à permissão', (
    tester,
  ) async {
    final system = _FakeSystem()..permissionAnswer = Completer<void>();
    final (c, _) = await _pump(tester, system: system);
    await tester.tap(_button('Focar'));
    await tester.pump();
    // Dois toques enquanto o Android pergunta: um pedido só.
    await tester.tap(_button('Focar'));
    await tester.pump();
    expect(system.permissionRequests, 1);
    expect(c.read(activeFocusProvider), isNull);
    _advance(const Duration(seconds: 30));
    system.permissionAnswer!.complete();
    await tester.pumpAndSettle();
    expect(c.read(activeFocusProvider)!.startedAt, _now);
    expect(find.byType(FocusPage), findsOneWidget);
  });

  testWidgets('minimizar: a tela encolhe descendo até a Barra do foco', (
    tester,
  ) async {
    await _pump(tester);
    await _openFocus(tester);
    await tester.tap(find.byTooltip('Minimizar'));
    await tester.pump();
    final screen = tester.getRect(find.byType(FocusPage));
    // No meio: menor que a tela e mais embaixo.
    await tester.pump(const Duration(milliseconds: 200));
    final mid = tester.getRect(find.byType(FocusPage));
    expect(mid.width, lessThan(screen.width));
    expect(mid.top, greaterThan(screen.top));
    await tester.pumpAndSettle();
    expect(find.byType(FocusPage), findsNothing);
    expect(find.byType(NexoFocusBar), findsOneWidget);
  });

  testWidgets('Início: tocar no cartão do plano abre o detalhe', (
    tester,
  ) async {
    await _pump(tester);
    await _tap(tester, find.text('Concurso Banco Horizonte'));
    expect(find.byType(PlanDetailPage), findsOneWidget);
  });

  testWidgets('calendário do plano marca o dia com registro manual', (
    tester,
  ) async {
    final (c, plan) = await _pump(tester);
    // Registrado à mão para anteontem (dentro dos 7 dias).
    final day = _today.addDays(-2);
    await c.read(plansRepositoryProvider).addSessions(plan.id, [
      DaySegment(
        day: day,
        startAt: DateTime(2026, 11, 2, 8),
        endAt: DateTime(2026, 11, 2, 9),
        durationSeconds: 3600,
      ),
    ], source: SessionSource.manual);
    c.read(routerProvider).push(AppRoutes.planDetailOf(plan.id));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Calendário'));
    final marked = find.bySemanticsLabel(RegExp('com registro manual'));
    expect(marked, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NexoCalendarDay),
        matching: find.byIcon(NexoCalendarDay.manualIcon),
      ),
      findsOneWidget,
    );
    expect(find.text('Registro manual'), findsOneWidget);
    await _tap(tester, marked);
    expect(find.text('1 sessão · 1 registro manual'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('fonte 2,0 sem estouro · ${dark ? 'escuro' : 'claro'}', (
      tester,
    ) async {
      final (c, plan) = await _pump(tester, dark: dark, textScale: 2);
      await _openFocus(tester);
      await _wait(tester, const Duration(minutes: 5));
      expect(tester.takeException(), isNull);
      await _tap(tester, _button('Encerrar'));
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(NexoFocusBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.read(routerProvider).push(AppRoutes.logHoursFor(plan.id));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
