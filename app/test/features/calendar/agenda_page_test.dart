import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/data/local_flags.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/ui.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/data/fake_auth_repository.dart';
import 'package:nexo/features/calendar/application/agenda_view.dart';
import 'package:nexo/features/calendar/presentation/agenda_page.dart';
import 'package:nexo/features/plans/application/plans_providers.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';
import 'package:nexo/features/plans/presentation/plan_detail_page.dart';
import 'package:nexo/features/tasks/application/tasks_providers.dart';
import 'package:nexo/features/tasks/domain/task.dart';
import 'package:nexo/features/tasks/presentation/task_form_page.dart';

// Quarta, 04/11/2026, 10:00. A semana vai de dom 1/11 a sáb 7/11.
final _now = DateTime(2026, 11, 4, 10);
const _today = LocalDate(2026, 11, 4);

/// App logado na Agenda, com o plano "Concurso Banco Horizonte" (19:00,
/// 45 min, [frequency]) e as tarefas de [tasks] (título e prazo).
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool dark = false,
  double textScale = 1,
  PlanFrequency frequency = const DailyFrequency(),
  List<(String, DateTime)> tasks = const [],
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
  await c
      .read(plansRepositoryProvider)
      .createPlan(
        Plan(
          id: '',
          name: 'Concurso Banco Horizonte',
          startDate: _today.addDays(-10),
          endDate: _today.addDays(100),
          frequency: frequency,
          dailyGoalMinutes: 45,
          studyTime: '19:00',
        ),
      );
  final repo = c.read(tasksRepositoryProvider);
  for (final (title, due) in tasks) {
    await repo.createTask(NexoTask(id: '', title: title, dueAt: due));
  }
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(LucideIcons.calendarDays));
  await tester.pumpAndSettle();
  return c;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.widgetWithText(NexoButton, label);

/// Seis tarefas na quinta, 5/11 (limite padrão: 5).
final _sixOnThursday = [
  for (var i = 1; i <= 6; i++) ('Tarefa $i', DateTime(2026, 11, 5, 8 + i)),
];

void main() {
  test('textos do período e a sugestão do "Mover para"', () {
    expect(weekRangeText(const LocalDate(2026, 11, 1)), '1 a 7 de novembro');
    expect(
      weekRangeText(const LocalDate(2026, 11, 29)),
      '29 de novembro a 5 de dezembro',
    );
    expect(
      weekRangeText(const LocalDate(2026, 12, 27)),
      '27 de dezembro de 2026 a 2 de janeiro de 2027',
    );
    final load = {_today.addDays(1): 5, _today.addDays(2): 6};
    expect(
      suggestedMoveDay(load, _today, today: _today, threshold: 5),
      _today.addDays(3),
    );
  });

  testWidgets('01 Semana: hoje selecionado, Planos e Tarefas do dia', (
    tester,
  ) async {
    await _pump(
      tester,
      tasks: [
        ('Trabalho de modelagem do banco', DateTime(2026, 11, 4, 18)),
        ('Resumo do capítulo 2', DateTime(2026, 11, 4, 21)),
        ('Prova de Cálculo II', DateTime(2026, 11, 6, 8)),
      ],
    );
    expect(find.byType(AgendaPage), findsOneWidget);
    expect(find.text('1 a 7 de novembro'), findsOneWidget);
    expect(find.text('Hoje, qua 4 de novembro'), findsOneWidget);
    expect(find.text('Planos'), findsWidgets);
    expect(find.text('1 plano'), findsOneWidget);
    expect(find.text('19:00 · meta 45 min'), findsOneWidget);
    expect(find.text('2 tarefas'), findsOneWidget);
    expect(find.text('Trabalho de modelagem do banco'), findsOneWidget);
    expect(find.text('Prova de Cálculo II'), findsNothing);
    // Pontos de carga só das tarefas; leitor de tela com a carga.
    expect(
      find.bySemanticsLabel('Quarta, 4 de novembro, 2 tarefas, hoje'),
      findsOneWidget,
    );

    // Tocar no plano abre o plano; voltar e tocar na tarefa abre a tarefa.
    await _tap(tester, find.text('Concurso Banco Horizonte'));
    expect(find.byType(PlanDetailPage), findsOneWidget);
    await _tap(tester, find.byTooltip('Voltar'));
    await _tap(tester, find.text('Resumo do capítulo 2'));
    expect(find.byType(TaskFormPage), findsOneWidget);
  });

  testWidgets('dia de hoje e selecionado: número em Emphasis', (tester) async {
    await _pump(tester);
    Text number(String day) => tester.widget<Text>(
      find.descendant(
        of: find.byType(NexoCalendarDay),
        matching: find.text(day),
      ),
    );
    final c = tester.element(find.byType(AgendaPage)).nexoColors;
    final regular = number('3').style!;
    // Hoje selecionado: OnPrimary, mais pesado que os outros dias.
    expect(number('4').style!.color, c.onPrimary);
    expect(
      number('4').style!.fontWeight!.value,
      greaterThan(regular.fontWeight!.value),
    );
    // Outro dia selecionado: hoje fica em Primary (com o anel).
    await _tap(tester, find.bySemanticsLabel('Quinta, 5 de novembro'));
    expect(number('4').style!.color, c.primary);
    expect(number('5').style!.color, c.onPrimary);
    expect(regular.color, c.onSurface);
  });

  testWidgets('setas trocam a semana; o dia selecionado vai junto', (
    tester,
  ) async {
    await _pump(tester);
    await _tap(tester, find.byTooltip('Próxima semana'));
    expect(find.text('8 a 14 de novembro'), findsOneWidget);
    expect(find.text('Qua, 11 de novembro'), findsOneWidget);
    await _tap(tester, find.byTooltip('Semana anterior'));
    expect(find.text('Hoje, qua 4 de novembro'), findsOneWidget);
  });

  testWidgets('carrossel: as semanas trocam lado a lado, sem sobrepor', (
    tester,
  ) async {
    await _pump(tester);
    Finder day(String n) => find.descendant(
      of: find.byType(NexoCalendarDay),
      matching: find.text(n),
    );
    await tester.tap(find.byTooltip('Próxima semana'));
    await tester.pump();
    // No meio (Long = 350 ms): a semana antiga (1 a 7) sai pela esquerda
    // e a nova (8 a 14) entra pela direita, encostadas.
    await tester.pump(const Duration(milliseconds: 175));
    expect(day('7'), findsOneWidget);
    expect(day('8'), findsOneWidget);
    expect(
      tester.getRect(day('8')).left,
      greaterThan(tester.getRect(day('7')).right),
    );
    expect(tester.getRect(day('1')).left, lessThan(0));
    // Sem esmaecer: nenhum dia meio transparente.
    expect(
      find.descendant(
        of: find.byType(AnimatedSwitcher),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(day('7'), findsNothing);
    expect(find.text('8 a 14 de novembro'), findsOneWidget);

    // Voltar: a semana de antes entra pela esquerda.
    await tester.tap(find.byTooltip('Semana anterior'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 175));
    expect(
      tester.getRect(day('7')).right,
      lessThan(tester.getRect(day('8')).left),
    );
    await tester.pumpAndSettle();

    // Mês: a mesma troca pelas setas.
    await _tap(tester, find.text('Mês'));
    await tester.tap(find.byTooltip('Próximo mês'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 175));
    expect(find.text('Dezembro de 2026'), findsOneWidget);
    expect(find.byType(NexoCalendarDay), findsNWidgets(30 + 31));
    await tester.pumpAndSettle();
    expect(find.byType(NexoCalendarDay), findsNWidgets(31));
  });

  testWidgets('carrossel com "reduzir movimento": corte seco', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pump(tester);
    await tester.tap(find.byTooltip('Próxima semana'));
    await tester.pump();
    await tester.pump();
    expect(find.text('7'), findsNothing);
    expect(find.text('8 a 14 de novembro'), findsOneWidget);
  });

  testWidgets('02 e 03: dia carregado, Reorganizar e mover com Desfazer', (
    tester,
  ) async {
    final c = await _pump(tester, tasks: _sixOnThursday);
    final thursday = find.bySemanticsLabel(
      'Quinta, 5 de novembro, sobrecarregado: 6 tarefas',
    );
    expect(thursday, findsOneWidget);
    await _tap(tester, thursday);
    expect(find.text('Dia carregado'), findsOneWidget);
    expect(find.text('6 tarefas neste dia. Seu limite é 5.'), findsOneWidget);

    await _tap(tester, find.text('Reorganizar'));
    expect(find.text('Reorganizar qui, 05/11'), findsOneWidget);
    expect(find.text('Escolha o que pode ir para outro dia.'), findsOneWidget);
    // Sugestão: sexta, 6/11 (sem tarefas). Nada marcado, nada se move.
    expect(find.text('Sex, 06/11 · 0 tarefas'), findsOneWidget);
    expect(
      find.text('Sugestão: o próximo dia abaixo do seu limite.'),
      findsOneWidget,
    );
    expect(
      tester.widget<NexoButton>(_button('Mover tarefas')).onPressed,
      isNull,
    );
    // No painel (a lista do dia fica por baixo).
    Finder inSheet(String title) => find.descendant(
      of: find.byType(NexoCheckbox),
      matching: find.text(title),
    );
    await _tap(tester, inSheet('Tarefa 5'));
    await _tap(tester, inSheet('Tarefa 6'));
    await _tap(tester, _button('Mover 2 tarefas'));
    expect(find.text('2 tarefas movidas para sex, 06/11.'), findsOneWidget);

    var tasks = await c.read(tasksRepositoryProvider).watchTasks().first;
    final moved = tasks.firstWhere((t) => t.title == 'Tarefa 6');
    expect(moved.dueAt, DateTime(2026, 11, 6, 14));
    // Com 4, o dia sai da sobrecarga.
    expect(find.text('Dia carregado'), findsNothing);

    await _tap(tester, find.text('Desfazer'));
    tasks = await c.read(tasksRepositoryProvider).watchTasks().first;
    expect(
      tasks.firstWhere((t) => t.title == 'Tarefa 6').dueAt,
      DateTime(2026, 11, 5, 14),
    );
  });

  testWidgets('05 dia sem nada: folga do plano e "Criar uma tarefa"', (
    tester,
  ) async {
    // O plano só tem segunda: sábado, 7/11, é folga.
    await _pump(tester, frequency: WeekdaysFrequency({1}));
    await _tap(tester, find.bySemanticsLabel('Sábado, 7 de novembro'));
    expect(find.text('Nada marcado para este dia'), findsOneWidget);
    expect(
      find.text(
        'Folga do plano Concurso Banco Horizonte. Aproveite para descansar.',
      ),
      findsOneWidget,
    );
    await _tap(tester, _button('Criar uma tarefa'));
    expect(find.byType(TaskFormPage), findsOneWidget);
  });

  testWidgets('06 Mês: grade com a carga e o resumo do dia tocado', (
    tester,
  ) async {
    await _pump(tester, tasks: _sixOnThursday);
    await _tap(tester, find.text('Mês'));
    expect(find.text('Novembro de 2026'), findsOneWidget);
    expect(find.byType(NexoCalendarDay), findsNWidgets(30));
    await _tap(
      tester,
      find.bySemanticsLabel('Quinta, 5 de novembro, sobrecarregado: 6 tarefas'),
    );
    expect(find.text('Dia carregado'), findsOneWidget);
    await _tap(tester, find.byTooltip('Próximo mês'));
    expect(find.text('Dezembro de 2026'), findsOneWidget);
    expect(find.text('Ter, 1 de dezembro'), findsOneWidget);
    // Voltar para a Semana fica na semana do dia selecionado.
    await _tap(tester, find.text('Semana'));
    expect(find.text('29 de novembro a 5 de dezembro'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('fonte 2,0 sem estouro · ${dark ? 'escuro' : 'claro'}', (
      tester,
    ) async {
      await _pump(tester, dark: dark, textScale: 2, tasks: _sixOnThursday);
      expect(tester.takeException(), isNull);
      await _tap(
        tester,
        find.bySemanticsLabel(
          'Quinta, 5 de novembro, sobrecarregado: 6 tarefas',
        ),
      );
      expect(tester.takeException(), isNull);
      await _tap(tester, find.text('Reorganizar'));
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      // Com a fonte grande, o topo saiu da tela rolando até o aviso.
      await tester.scrollUntilVisible(
        find.text('Mês'),
        -200,
        scrollable: find
            .descendant(
              of: find.byType(AgendaPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await _tap(tester, find.text('Mês'));
      expect(tester.takeException(), isNull);
    });
  }
}
