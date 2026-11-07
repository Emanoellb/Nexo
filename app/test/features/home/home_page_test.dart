import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/data/connectivity.dart';
import 'package:nexo/core/data/local_flags.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/core/ui/ui.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/data/fake_auth_repository.dart';
import 'package:nexo/features/focus/domain/focus_session.dart';
import 'package:nexo/features/focus/domain/session_split.dart';
import 'package:nexo/features/home/presentation/home_page.dart';
import 'package:nexo/features/plans/application/plans_providers.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';
import 'package:nexo/features/tasks/application/tasks_providers.dart';
import 'package:nexo/features/tasks/domain/task.dart';

// Quarta, 04/11/2026, 10:00.
final _now = DateTime(2026, 11, 4, 10);
const _today = LocalDate(2026, 11, 4);

class _FakeConnectivity implements ConnectivitySource {
  final controller = StreamController<bool>.broadcast();
  bool online = true;

  @override
  Stream<bool> watchOnline() async* {
    yield online;
    yield* controller.stream;
  }
}

/// App logado na conta de protótipo, sem dados de exemplo (os testes montam
/// o que precisam), num celular de 360 × 800.
Future<ProviderContainer> _pumpHome(
  WidgetTester tester, {
  bool dark = false,
  _FakeConnectivity? connectivity,
  List<Override> overrides = const [],
  bool settle = true,
  DateTime Function()? clock,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
        clockProvider.overrideWithValue(clock ?? () => _now),
        localFlagsProvider.overrideWithValue(
          InMemoryLocalFlags(
            firstOpenDone: true,
            themePreference: dark ? 'dark' : 'light',
          ),
        ),
        connectivitySourceProvider.overrideWithValue(
          connectivity ?? _FakeConnectivity(),
        ),
        ...overrides,
      ],
      child: const NexoApp(),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(NexoApp)));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.widgetWithText(NexoButton, label);

/// Plano principal de 90 min por dia, iniciado 22 dias atrás, com [doneToday]
/// minutos hoje, e tarefas variadas.
Future<Plan> _seedDailyUse(
  ProviderContainer c, {
  int doneToday = 70,
  PlanFrequency frequency = const DailyFrequency(),
}) async {
  final plans = c.read(plansRepositoryProvider);
  final plan = await plans.createPlan(
    Plan(
      id: '',
      name: 'Concurso Banco Horizonte',
      startDate: _today.addDays(-22),
      endDate: _today.addDays(277),
      frequency: frequency,
      dailyGoalMinutes: 90,
    ),
  );
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
  final tasks = c.read(tasksRepositoryProvider);
  for (final (title, due) in [
    ('Lista de exercícios 3', DateTime(2026, 11, 3, 23, 59)),
    ('Trabalho de modelagem do banco', DateTime(2026, 11, 4, 18)),
    ('Resumo do capítulo 2', DateTime(2026, 11, 4, 21)),
    ('Revisar UML', DateTime(2026, 11, 4, 22)),
    ('Entrega do relatório parcial', DateTime(2026, 11, 6, 23, 59)),
  ]) {
    await tasks.createTask(NexoTask(id: '', title: title, dueAt: due));
  }
  return plan;
}

/// Plano extra ativo (para "Escolher plano principal").
Future<Plan> _otherPlan(ProviderContainer c) => c
    .read(plansRepositoryProvider)
    .createPlan(
      Plan(
        id: '',
        name: 'Inglês para intercâmbio',
        startDate: _today.addDays(-5),
        endDate: _today.addDays(60),
        frequency: const DailyFrequency(),
        dailyGoalMinutes: 45,
      ),
    );

void main() {
  testWidgets('02 → 05: primeiros passos até a primeira sessão', (
    tester,
  ) async {
    await _pumpHome(tester);

    // 02 Vazio.
    expect(find.text('Seu dia começa aqui'), findsOneWidget);
    expect(find.text('0 de 3'), findsOneWidget);
    expect(find.textContaining('pelo + da barra'), findsOneWidget);

    // 03 Primeira tarefa.
    await _tap(tester, _button('Criar minha primeira tarefa'));
    expect(find.text('Boa, primeira tarefa criada'), findsOneWidget);
    expect(find.text('1 de 3'), findsOneWidget);
    expect(find.text('Hoje'), findsWidgets);
    expect(find.text('Tarefa de exemplo 1'), findsOneWidget);

    // 04 Primeiro plano: o cartão do plano e a linha 2 de 3.
    await _tap(tester, _button('Criar meu primeiro plano'));
    expect(find.text('PLANO DE AÇÃO'), findsOneWidget);
    expect(find.text('Dia 1 de 300'), findsOneWidget);
    expect(find.text('Primeiros passos · 2 de 3'), findsOneWidget);
    expect(find.text('Comece sua sequência hoje'), findsOneWidget);

    // 05 Primeira sessão: a linha some e a Snackbar avisa.
    await _tap(tester, _button('Focar'));
    expect(find.text('Primeiros passos concluídos.'), findsOneWidget);
    expect(find.textContaining('Primeiros passos ·'), findsNothing);
    expect(find.text('Hoje · 25 min de 1h 30min'), findsOneWidget);
    expect(find.text('Faltam 1h 05min'), findsOneWidget);
  });

  testWidgets('dispensar os primeiros passos não traz o cartão de volta', (
    tester,
  ) async {
    await _pumpHome(tester);
    // A etapa 2 também é tocável (plano antes da tarefa).
    await _tap(tester, find.text('Crie seu primeiro plano'));
    expect(find.text('Primeiros passos · 1 de 3'), findsOneWidget);
    expect(
      find.text('Falta sua primeira tarefa: crie pelo + da barra.'),
      findsOneWidget,
    );
    await _tap(tester, find.byTooltip('Dispensar primeiros passos'));
    expect(find.textContaining('Primeiros passos'), findsNothing);
  });

  testWidgets('06 uso diário: plano, Hoje com até 3 e Próximas entregas', (
    tester,
  ) async {
    final c = await _pumpHome(tester);
    await _seedDailyUse(c);
    await tester.pumpAndSettle();

    expect(find.text('Dia 23 de 300'), findsOneWidget);
    expect(find.text('Hoje · 1h 10min de 1h 30min'), findsOneWidget);
    expect(find.text('Faltam 20 min'), findsOneWidget);
    // Hoje: 4 tarefas (1 atrasada + 3 de hoje), só 3 na lista (Miller).
    expect(find.text('4 tarefas'), findsOneWidget);
    expect(find.text('Atrasada · ontem, 23:59'), findsOneWidget);
    expect(find.text('Hoje · 18:00'), findsOneWidget);
    expect(find.text('Revisar UML'), findsNothing);
    expect(find.textContaining('Primeiros passos'), findsNothing);

    await tester.scrollUntilVisible(find.text('Sex · 23:59'), 200);
    expect(find.text('Próximas entregas'), findsOneWidget);
    expect(find.text('Entrega do relatório parcial'), findsOneWidget);
  });

  testWidgets('07 → 08: finalizar abaixo da meta, +3 pontos e desfazer', (
    tester,
  ) async {
    final c = await _pumpHome(tester);
    await _seedDailyUse(c);
    await tester.pumpAndSettle();

    await _tap(tester, _button('Finalizar o dia'));
    expect(find.text('Finalizar o dia agora?'), findsOneWidget);
    expect(find.textContaining('com 20 min a menos'), findsOneWidget);

    // "Agora não" fecha sem finalizar.
    await _tap(tester, _button('Agora não'));
    expect(find.text('Finalizar o dia agora?'), findsNothing);

    await _tap(tester, _button('Finalizar o dia'));
    await _tap(
      tester,
      find.descendant(
        of: find.byType(NexoDialog),
        matching: _button('Finalizar o dia'),
      ),
    );
    expect(find.text('Dia cumprido · 1h 10min'), findsOneWidget);
    expect(find.text('−20 min da meta'), findsOneWidget);
    expect(_button('Estudar mais'), findsOneWidget);
    expect(_button('Finalizar o dia'), findsNothing);
    expect(find.text('Dia finalizado com 20 min a menos.'), findsOneWidget);

    Future<int> points() async =>
        (await c
                .read(userProfileRepositoryProvider)
                .watchProfile(FakeAuthRepository.prototypeUser.uid)
                .first)!
            .points;
    expect(await points(), 3);

    await _tap(tester, _button('Desfazer'));
    expect(_button('Finalizar o dia'), findsOneWidget);
    expect(await points(), 0);
  });

  testWidgets('09: meta batida mostra o resultado, sem Finalizar', (
    tester,
  ) async {
    final c = await _pumpHome(tester);
    await _seedDailyUse(c, doneToday: 105);
    await tester.pumpAndSettle();
    // +15 min (≥ 10 acima da meta): com horas a mais.
    expect(find.text('Dia cumprido · 1h 45min'), findsOneWidget);
    expect(find.text('+15 min da meta'), findsOneWidget);
    expect(_button('Estudar mais'), findsOneWidget);
    expect(_button('Finalizar o dia'), findsNothing);
  });

  testWidgets('09: até 9 min acima da meta é "Na meta"', (tester) async {
    final c = await _pumpHome(tester);
    await _seedDailyUse(c, doneToday: 95);
    await tester.pumpAndSettle();
    expect(find.text('Dia cumprido · 1h 35min'), findsOneWidget);
    expect(find.text('Na meta'), findsOneWidget);
  });

  group('pacote B: estados do cartão do plano', () {
    testWidgets('0 min: só Focar, sem "Finalizar o dia"', (tester) async {
      final c = await _pumpHome(tester);
      await _seedDailyUse(c, doneToday: 0);
      await tester.pumpAndSettle();
      expect(find.text('Hoje · 0 min de 1h 30min'), findsOneWidget);
      expect(_button('Focar'), findsOneWidget);
      expect(_button('Finalizar o dia'), findsNothing);
    });

    testWidgets('folga: "Estudar mesmo assim" e o próximo dia', (tester) async {
      final c = await _pumpHome(tester);
      // Quarta (hoje) fora de segunda e sexta.
      await _seedDailyUse(
        c,
        doneToday: 0,
        frequency: WeekdaysFrequency({1, 5}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Folga'), findsOneWidget);
      expect(find.text('Hoje é folga neste plano'), findsOneWidget);
      expect(find.text('Próximo: sex, 06/11'), findsOneWidget);
      expect(_button('Estudar mesmo assim'), findsOneWidget);
      expect(_button('Focar'), findsNothing);

      // Estudou na folga: vale como dia normal.
      await _tap(tester, _button('Estudar mesmo assim'));
      expect(find.text('Folga · estudo extra'), findsOneWidget);
      expect(find.text('Hoje · 25 min de 1h 30min'), findsOneWidget);
      expect(_button('Finalizar o dia'), findsOneWidget);
    });

    testWidgets('pausado: "Retomar plano" volta ao normal', (tester) async {
      final c = await _pumpHome(tester);
      final plan = await _seedDailyUse(c, doneToday: 0);
      await c
          .read(plansRepositoryProvider)
          .updatePlan(
            plan.copyWith(
              status: PlanStatus.paused,
              pauses: [PlanPause(start: _today.addDays(-2))],
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('Pausado'), findsOneWidget);
      expect(find.text('Pausado desde 2/11'), findsOneWidget);
      expect(find.text('Dias pausados não contam'), findsOneWidget);
      expect(find.textContaining('sequência mantida'), findsOneWidget);

      await _tap(tester, _button('Retomar plano'));
      expect(find.text('Pausado'), findsNothing);
      expect(find.text('Dia 23 de 300'), findsOneWidget);
      expect(_button('Focar'), findsOneWidget);
    });

    testWidgets('arquivado com outro ativo: escolher leva aos Planos', (
      tester,
    ) async {
      final c = await _pumpHome(tester);
      final plan = await _seedDailyUse(c);
      await _otherPlan(c);
      await c
          .read(plansRepositoryProvider)
          .updatePlan(plan.copyWith(status: PlanStatus.archived));
      await tester.pumpAndSettle();
      expect(find.text('Arquivado'), findsOneWidget);
      expect(find.text('Seu plano principal foi arquivado'), findsOneWidget);
      expect(find.textContaining('dias seguidos'), findsNothing);

      await _tap(tester, _button('Escolher plano principal'));
      expect(find.text('Em construção · bloco 3 · Planos'), findsOneWidget);
    });

    testWidgets('encerrado sem outro ativo: "Criar plano" vira o principal', (
      tester,
    ) async {
      final c = await _pumpHome(tester);
      final plan = await _seedDailyUse(c);
      await c
          .read(plansRepositoryProvider)
          .updatePlan(plan.copyWith(status: PlanStatus.completed));
      await tester.pumpAndSettle();
      expect(find.text('Encerrado'), findsOneWidget);
      expect(find.text('Seu plano principal foi encerrado'), findsOneWidget);

      await _tap(tester, _button('Criar plano'));
      expect(find.text('Plano de exemplo 1'), findsOneWidget);
      expect(find.text('Dia 1 de 300'), findsOneWidget);
    });
  });

  testWidgets('10: sem conexão mostra o alerta e mantém os dados', (
    tester,
  ) async {
    final connectivity = _FakeConnectivity()..online = false;
    final c = await _pumpHome(tester, connectivity: connectivity);
    await _seedDailyUse(c);
    await tester.pumpAndSettle();
    expect(find.text('Você está sem conexão'), findsOneWidget);
    expect(find.text('PLANO DE AÇÃO'), findsOneWidget);

    connectivity.controller.add(true);
    await tester.pumpAndSettle();
    expect(find.text('Você está sem conexão'), findsNothing);
  });

  testWidgets('01: carga demorada mostra o skeleton e anuncia', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpHome(
      tester,
      settle: false,
      overrides: [
        plansProvider.overrideWith((ref) => const Stream<List<Plan>>.empty()),
      ],
    );
    // Splash, entrada e o atraso do skeleton.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.bySemanticsLabel('Carregando o Início'), findsOneWidget);
    expect(find.byType(NexoSkeleton), findsWidgets);
    handle.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets(
      'diretrizes de alvo, rótulo e contraste (${dark ? 'escuro' : 'claro'})',
      (tester) async {
        final handle = tester.ensureSemantics();
        final c = await _pumpHome(tester, dark: dark);
        // Vazio.
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        // Uso diário.
        await _seedDailyUse(c);
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );
  }

  for (final scale in [1.3, 2.0]) {
    testWidgets('fonte ampliada ($scale) em 360 dp não estoura', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final c = await _pumpHome(tester);
      expect(tester.takeException(), isNull);
      await _seedDailyUse(c);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('à meia-noite o cartão vira o dia sozinho', (tester) async {
    var now = DateTime(2026, 11, 4, 23, 50);
    final c = await _pumpHome(tester, clock: () => now);
    await _seedDailyUse(c);
    await tester.pumpAndSettle();
    expect(find.text('Dia 23 de 300'), findsOneWidget);
    expect(find.text('Hoje · 1h 10min de 1h 30min'), findsOneWidget);

    // Passa da meia-noite: o timer da tela renova o "agora".
    now = DateTime(2026, 11, 5, 0, 1);
    await tester.pump(const Duration(minutes: 11));
    await tester.pumpAndSettle();
    expect(find.text('Dia 24 de 300'), findsOneWidget);
    expect(find.text('Hoje · 0 min de 1h 30min'), findsOneWidget);
  });

  testWidgets('no horário do prazo, a tarefa vira "Atrasada"', (tester) async {
    var now = DateTime(2026, 11, 4, 17, 55);
    final c = await _pumpHome(tester, clock: () => now);
    await _seedDailyUse(c);
    await tester.pumpAndSettle();
    expect(find.text('Hoje · 18:00'), findsOneWidget);

    now = DateTime(2026, 11, 4, 18, 0, 2);
    await tester.pump(const Duration(minutes: 6));
    await tester.pumpAndSettle();
    expect(find.text('Atrasada · hoje, 18:00'), findsOneWidget);
  });

  testWidgets('"Nova tarefa" do "+" abre a tela e não conclui os passos', (
    tester,
  ) async {
    await _pumpHome(tester);
    // Plano e sessão primeiro; falta a tarefa.
    await _tap(tester, find.text('Crie seu primeiro plano'));
    await _tap(tester, _button('Focar'));
    expect(find.text('Primeiros passos · 2 de 3'), findsOneWidget);

    // O "+" agora abre "Em construção" (decisão do usuário, 05/11/2026).
    await _tap(tester, find.byType(NexoFab));
    await _tap(tester, find.text('Nova tarefa'));
    expect(find.text('Em construção · bloco 7 · Tarefas'), findsOneWidget);
    expect(find.text('Primeiros passos concluídos.'), findsNothing);
  });

  testWidgets('última etapa pelo "Criar tarefa" do Hoje: só o aviso de '
      'conclusão', (tester) async {
    await _pumpHome(tester);
    // Plano e sessão primeiro; falta a tarefa.
    await _tap(tester, find.text('Crie seu primeiro plano'));
    await _tap(tester, _button('Focar'));
    expect(find.text('Primeiros passos · 2 de 3'), findsOneWidget);

    await _tap(tester, _button('Criar tarefa'));
    expect(find.text('Primeiros passos concluídos.'), findsOneWidget);
    expect(find.textContaining('criada para hoje'), findsNothing);
    expect(find.textContaining('Primeiros passos ·'), findsNothing);
  });

  testWidgets('tocar na tarefa abre o detalhe, como em Tarefas', (
    tester,
  ) async {
    final c = await _pumpHome(tester);
    await _seedDailyUse(c);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Trabalho de modelagem do banco'));
    expect(find.text('Em construção · bloco 7 · Tarefas'), findsOneWidget);
    expect(find.text('Detalhe da tarefa'), findsWidgets);
  });

  testWidgets('Focar sem concluir os passos ainda confirma a sessão', (
    tester,
  ) async {
    await _pumpHome(tester);
    // Plano sem tarefa: a sessão não conclui os 3 passos.
    await _tap(tester, find.text('Crie seu primeiro plano'));
    await _tap(tester, _button('Focar'));
    expect(find.text('Sessão de 25 min registrada.'), findsOneWidget);
  });
}
