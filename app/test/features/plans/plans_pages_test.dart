import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/features/focus/presentation/session_form_page.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/data/local_flags.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/core/ui/ui.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/data/fake_auth_repository.dart';
import 'package:nexo/features/goals/application/goals_providers.dart';
import 'package:nexo/features/plans/application/plans_providers.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';
import 'package:nexo/features/plans/presentation/create_plan_page.dart';
import 'package:nexo/features/plans/presentation/plan_detail_page.dart';
import 'package:nexo/features/progress/application/progress_actions.dart';
import 'package:nexo/features/subjects/application/subjects_providers.dart';

import 'plan_seed.dart';

/// App logado, sem dados de exemplo, na aba Planos (360 × [height]).
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool dark = false,
  double height = 1400,
  double textScale = 1,
  Future<void> Function(ProviderContainer)? seed,
}) async {
  tester.view.physicalSize = Size(1080, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
        clockProvider.overrideWithValue(() => seedNow),
        localFlagsProvider.overrideWithValue(
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
  if (seed != null) {
    await seed(c);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byIcon(LucideIcons.target).first);
  await tester.pumpAndSettle();
  return c;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _longPress(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.longPress(finder);
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.widgetWithText(NexoButton, label);

Plan _draft(
  String name, {
  PlanFrequency frequency = const DailyFrequency(),
  LocalDate start = const LocalDate(2026, 11, 1),
}) => Plan(
  id: '',
  name: name,
  startDate: start,
  endDate: start.addDays(179),
  frequency: frequency,
  dailyGoalMinutes: 45,
);

/// Principal (com histórico), ativo, ativo "× por semana", pausado,
/// encerrado e arquivado.
Future<void> _seedList(ProviderContainer c) async {
  final repo = c.read(plansRepositoryProvider);
  final progress = c.read(progressActionsProvider);
  final main = await seedPlanHistory(repo);
  await progress.setPrimaryPlan(main.plan.id);
  await repo.createPlan(_draft('Inglês para intercâmbio'));
  await repo.createPlan(
    _draft('Leitura de clássicos', frequency: TimesPerWeekFrequency(4)),
  );
  final paused = await repo.createPlan(_draft('Revisão de redação'));
  await progress.pausePlan(paused.id);
  final ended = await repo.createPlan(_draft('Curso de Python'));
  await progress.endPlanEarly(ended.id);
  final archived = await repo.createPlan(_draft('Violão'));
  await progress.archivePlan(archived.id);
}

void main() {
  testWidgets('Criar plano: 3 passos, erros, tópico com nova disciplina', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final c = await _pump(tester);
    expect(find.text('Seus planos aparecem aqui'), findsOneWidget);

    await _tap(tester, find.byType(NexoFab));
    await _tap(tester, find.text('Novo plano'));
    expect(find.byType(CreatePlanPage), findsOneWidget);
    expect(find.text('Passo 1 de 3 · O plano'), findsOneWidget);
    expect(find.text('Sem objetivo'), findsOneWidget);

    // Passo 1: erros.
    await _tap(tester, _button('Continuar'));
    expect(find.text('Dê um nome ao plano.'), findsOneWidget);
    expect(find.text('Escolha o fim do plano.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Concurso Banco Horizonte');
    await _tap(tester, find.bySemanticsLabel('Fim'));
    await _tap(tester, find.text('OK'));
    await _tap(tester, _button('Continuar'));

    // Passo 2: dias da semana, meta e aviso.
    expect(find.text('Passo 2 de 3 · Ritmo'), findsOneWidget);
    await _tap(tester, find.text('Dias da semana'));
    expect(find.bySemanticsLabel('segunda'), findsOneWidget);
    await _tap(tester, find.byTooltip('Aumentar'));
    expect(find.text('1h 15min'), findsOneWidget);
    expect(find.text('15 min antes'), findsOneWidget);
    await _tap(tester, find.text('Avisar antes do horário'));
    expect(find.text('Antecedência'), findsNothing);
    await _tap(tester, find.text('Avisar antes do horário'));
    await _tap(tester, _button('Continuar'));

    // Passo 3: tópico com uma disciplina nova, no mesmo painel.
    expect(find.text('Passo 3 de 3 · Tópicos'), findsOneWidget);
    await _tap(tester, find.text('Adicionar tópico'));
    expect(find.text('Novo tópico'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(NexoBottomSheet),
        matching: find.byType(TextField),
      ),
      'Juros compostos',
    );
    await _tap(tester, find.bySemanticsLabel('Disciplina'));
    await _tap(tester, find.text('Nova disciplina…'));
    expect(find.text('Nova disciplina'), findsOneWidget);
    expect(find.byTooltip('Voltar'), findsWidgets);
    await tester.enterText(
      find.descendant(
        of: find.byType(NexoBottomSheet),
        matching: find.byType(TextField),
      ),
      'Matemática financeira',
    );
    await _tap(tester, _button('Salvar disciplina'));
    expect(find.text('Novo tópico'), findsOneWidget);
    expect(find.text('Matemática financeira'), findsOneWidget);
    await _tap(tester, _button('Salvar tópico'));
    expect(find.text('Disciplina: Matemática financeira'), findsOneWidget);

    await _tap(tester, _button('Criar plano'));
    expect(find.byType(CreatePlanPage), findsNothing);
    expect(find.text('Plano criado.'), findsOneWidget);
    expect(find.text('Ver'), findsOneWidget);

    final plan =
        (await c.read(plansRepositoryProvider).watchPlans().first).single;
    expect(plan.name, 'Concurso Banco Horizonte');
    expect(plan.frequency, WeekdaysFrequency({1, 2, 3, 4, 5}));
    expect(plan.dailyGoalMinutes, 75);
    expect(plan.studyTime, '19:00');
    expect(plan.reminderBefore, PlanReminderBefore.standard);
    final topic =
        (await c.read(plansRepositoryProvider).watchTopics(plan.id).first)
            .single;
    final subject =
        (await c.read(subjectsRepositoryProvider).watchSubjects().first).single;
    expect(topic.name, 'Juros compostos');
    expect(topic.subjectId, subject.id);
    // O primeiro plano vira o principal.
    expect(find.text('Principal'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('lista por status; Concluídos e Arquivados recolhidos', (
    tester,
  ) async {
    await _pump(tester, seed: _seedList);
    for (final header in ['Principal', 'Ativos', 'Pausados']) {
      expect(find.text(header), findsOneWidget);
    }
    expect(find.text('Concurso Banco Horizonte'), findsOneWidget);
    expect(find.text('4× por semana'), findsOneWidget);
    expect(find.text('0 de 4 dias nesta semana'), findsOneWidget);
    expect(
      find.text('Pausado desde hoje · dias pausados não contam'),
      findsOneWidget,
    );
    expect(find.text('Curso de Python'), findsNothing);
    await _tap(tester, find.text('Concluídos e encerrados'));
    expect(find.text('Curso de Python'), findsOneWidget);
    expect(find.text('Encerrado em 04/11/2026'), findsOneWidget);
    expect(find.text('Violão'), findsNothing);
  });

  testWidgets('menu: pausar com Desfazer; excluir pede confirmação', (
    tester,
  ) async {
    final c = await _pump(tester, seed: _seedList);
    await _longPress(tester, find.text('Inglês para intercâmbio'));
    for (final item in [
      'Definir como principal',
      'Pausar plano',
      'Encerrar antes',
      'Arquivar',
      'Excluir plano',
    ]) {
      expect(find.text(item), findsOneWidget);
    }
    await _tap(tester, find.text('Pausar plano'));
    expect(find.text('Plano pausado.'), findsOneWidget);
    await _tap(tester, find.text('Desfazer'));
    final plans = await c.read(plansRepositoryProvider).watchPlans().first;
    expect(
      plans.firstWhere((p) => p.name == 'Inglês para intercâmbio').status,
      PlanStatus.active,
    );

    await _longPress(tester, find.text('Inglês para intercâmbio'));
    await _tap(tester, find.text('Excluir plano'));
    expect(find.text('Excluir plano?'), findsOneWidget);
    await _tap(tester, _button('Excluir plano'));
    expect(find.text('Plano excluído.'), findsOneWidget);
    expect(find.text('Inglês para intercâmbio'), findsNothing);
  });

  testWidgets('objetivos: criar, ligar um plano e excluir', (tester) async {
    final c = await _pump(tester, seed: _seedList);
    await _tap(tester, find.text('Objetivos'));
    expect(find.text('Seus objetivos aparecem aqui'), findsOneWidget);
    await _tap(tester, _button('Criar um objetivo'));
    await tester.enterText(
      find
          .descendant(
            of: find.byType(NexoBottomSheet),
            matching: find.byType(TextField),
          )
          .first,
      'Intercâmbio em Dublin',
    );
    await _tap(tester, _button('Salvar objetivo'));
    expect(find.text('Objetivo criado.'), findsOneWidget);
    expect(find.text('Nenhum plano ainda'), findsOneWidget);

    await _tap(tester, find.text('Intercâmbio em Dublin'));
    expect(find.text('Planos ligados'), findsOneWidget);
    await _tap(tester, find.text('Ligar um plano'));
    expect(find.text('Ligar planos a este objetivo'), findsOneWidget);
    await _tap(tester, find.text('Inglês para intercâmbio'));
    await _tap(tester, _button('Ligar 1 plano'));
    expect(find.text('Plano ligado.'), findsOneWidget);
    final goal =
        (await c.read(goalsRepositoryProvider).watchGoals().first).single;
    final plans = await c.read(plansRepositoryProvider).watchPlans().first;
    expect(
      plans.firstWhere((p) => p.name == 'Inglês para intercâmbio').goalId,
      goal.id,
    );

    await _tap(tester, find.byTooltip('Mais opções'));
    await _tap(tester, find.text('Excluir objetivo'));
    expect(find.text('Excluir objetivo?'), findsOneWidget);
    await _tap(tester, _button('Excluir objetivo'));
    expect(find.text('Objetivo excluído.'), findsOneWidget);
    expect(find.text('Seus objetivos aparecem aqui'), findsOneWidget);
  });

  group('detalhe do plano', () {
    Future<ProviderContainer> open(
      WidgetTester tester, {
      bool dark = false,
      double textScale = 1,
      double height = 1400,
    }) async {
      final c = await _pump(
        tester,
        dark: dark,
        textScale: textScale,
        height: height,
        seed: _seedList,
      );
      await _tap(tester, find.text('Concurso Banco Horizonte'));
      expect(find.byType(PlanDetailPage), findsOneWidget);
      return c;
    }

    testWidgets('Visão geral: hoje, até ontem, dias, tópicos e plano', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      // Alta o bastante para a Visão geral inteira ser montada.
      await open(tester, height: 3200);
      expect(find.text('Visão geral'), findsOneWidget);
      expect(find.text('Hoje'), findsWidgets);
      expect(_button('Focar'), findsOneWidget);
      expect(find.text('Até ontem'), findsOneWidget);
      expect(find.text('3h 45min'), findsOneWidget);
      expect(find.text('de 10h planejadas'), findsOneWidget);
      expect(find.text('−6h 15min'), findsOneWidget);
      expect(find.text('maior: 3 dias'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.bySemanticsLabel('Não cumprido: 6 dias'), findsOneWidget);
      expect(find.text('Só deste plano · 1h 37min'), findsNWidgets(2));
      expect(find.text('19:00 · aviso 15 min antes'), findsOneWidget);
      expect(find.text('Todos os dias'), findsOneWidget);
      // Focar é um botão próprio, não parte do texto do cartão.
      expect(find.bySemanticsLabel('Focar'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('o fim da Visão geral rola para acima da barra', (
      tester,
    ) async {
      await _pump(tester, height: 800, seed: _seedList);
      await _tap(tester, find.text('Concurso Banco Horizonte'));
      await tester.fling(find.text('Até ontem'), const Offset(0, -3000), 3000);
      await tester.pumpAndSettle();
      final last = tester.getRect(find.text('19:00 · aviso 15 min antes'));
      final bar = tester.getRect(find.byType(NexoBottomBar));
      expect(last.bottom, lessThanOrEqualTo(bar.top));
    });

    testWidgets('tópico: excluir com Desfazer', (tester) async {
      await open(tester);
      await _tap(tester, find.text('Porcentagem'));
      expect(find.text('Editar tópico'), findsOneWidget);
      await _tap(tester, _button('Excluir tópico'));
      expect(find.text('Tópico excluído.'), findsOneWidget);
      expect(find.text('Porcentagem'), findsNothing);
      await _tap(tester, find.text('Desfazer'));
      expect(find.text('Porcentagem'), findsOneWidget);
    });

    testWidgets('Calendário e Sessões', (tester) async {
      await open(tester);
      await _tap(tester, find.text('Calendário'));
      expect(find.text('Novembro de 2026'), findsOneWidget);
      expect(find.text('Qua, 4 de novembro'), findsOneWidget);
      await _tap(tester, find.bySemanticsLabel(RegExp(r'^Seg, 2 de novembro')));
      expect(find.text('Na meta · 1h'), findsOneWidget);
      expect(find.text('1 sessão · Juros simples'), findsOneWidget);

      await _tap(tester, find.text('Sessões'));
      expect(find.text('Seg, 2 de novembro'), findsOneWidget);
      expect(find.text('1h · Juros simples'), findsOneWidget);
      // Registrar horas já vem com este plano; tocar na sessão abre o
      // Editar sessão.
      await _tap(tester, _button('Registrar horas'));
      expect(find.byType(SessionFormPage), findsOneWidget);
      expect(find.text('Concurso Banco Horizonte'), findsWidgets);
      await _tap(tester, find.byTooltip('Fechar'));
      await _tap(tester, find.text('1h · Juros simples'));
      expect(find.text('Editar sessão'), findsOneWidget);
      expect(_button('Excluir sessão'), findsOneWidget);
    });

    testWidgets('Editar plano: meta nova vale a partir de amanhã', (
      tester,
    ) async {
      final c = await open(tester);
      await _tap(tester, find.byTooltip('Editar plano'));
      expect(find.text('Editar plano'), findsOneWidget);
      expect(find.text('Já começou'), findsOneWidget);
      await _tap(tester, find.byTooltip('Aumentar'));
      await _tap(tester, _button('Salvar'));
      expect(find.text('Alterações salvas.'), findsOneWidget);
      final plans = await c.read(plansRepositoryProvider).watchPlans().first;
      final plan = plans.firstWhere(
        (p) => p.name == 'Concurso Banco Horizonte',
      );
      final versions = await c
          .read(plansRepositoryProvider)
          .watchVersions(plan.id)
          .first;
      expect(versions.last.effectiveFrom, seedToday.addDays(1));
      expect(versions.last.dailyGoalMinutes, 75);
      expect(plan.dailyGoalMinutes, 75);
    });

    testWidgets('encerrado: Relatório e Arquivar plano', (tester) async {
      await _pump(tester, seed: _seedList);
      await _tap(tester, find.text('Concluídos e encerrados'));
      await _tap(tester, find.text('Curso de Python'));
      expect(find.text('Relatório'), findsOneWidget);
      expect(find.text('Resultado final'), findsOneWidget);
      expect(find.text('Plano concluído em 04/11/2026.'), findsNothing);
      expect(
        find.textContaining('Plano encerrado em 04/11/2026, antes do fim'),
        findsOneWidget,
      );
      expect(_button('Arquivar plano'), findsOneWidget);
    });

    for (final dark in [false, true]) {
      testWidgets('acessibilidade e fonte 2,0 (${dark ? 'escuro' : 'claro'})', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await open(tester, dark: dark, textScale: 2);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await _tap(tester, find.text('Calendário'));
        expect(tester.takeException(), isNull);
        // Cada dia da grade com alvo ≥ 48 em 360 dp.
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });

  for (final dark in [false, true]) {
    testWidgets(
      'lista e Criar plano com fonte 2,0 (${dark ? 'escuro' : 'claro'})',
      (tester) async {
        final handle = tester.ensureSemantics();
        // Alta o bastante para o passo 2 caber sem texto cortado na borda
        // da rolagem (a medição de contraste lê texto cortado como 1:1).
        await _pump(
          tester,
          dark: dark,
          textScale: 2,
          height: 2600,
          seed: _seedList,
        );
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await _tap(tester, find.byType(NexoFab));
        await _tap(tester, find.text('Novo plano'));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tester.enterText(find.byType(TextField), 'Treino');
        await _tap(tester, find.bySemanticsLabel('Fim'));
        await _tap(tester, find.text('OK'));
        await _tap(tester, _button('Continuar'));
        await _tap(tester, find.text('Dias da semana'));
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );
  }
}
