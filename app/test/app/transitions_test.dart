import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/features/profile/presentation/profile_page.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/app/router/nexo_transitions.dart';
import 'package:nexo/app/router/routes.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/ui.dart';
import 'package:nexo/features/home/presentation/home_page.dart';
import 'package:nexo/features/plans/presentation/create_plan_page.dart';
import 'package:nexo/features/tasks/presentation/tasks_page.dart';
import 'package:nexo/features/plans/application/plans_providers.dart';
import 'package:nexo/features/subjects/application/subjects_providers.dart';
import 'package:nexo/features/tasks/application/tasks_providers.dart';
import 'package:nexo/features/tasks/domain/task.dart';

import '../features/plans/plan_seed.dart';

import '../fakes/fakes.dart';

/// Padrão de transições (`pen.dev/notas/transicoes-especificacao.md`,
/// aprovado em 08/11/2026).
Future<void> _pump(WidgetTester tester, {bool reduceMotion = false}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...fakeBackend(
          auth: FakeAuthRepository.signedIn(),
          flags: InMemoryLocalFlags(
            firstOpenDone: true,
            themePreference: 'light',
          ),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 4, 10)),
      ],
      child: reduceMotion
          ? const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: NexoApp(),
            )
          : const NexoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(HomePage)));

NexoPageRoute<dynamic> _topRoute(WidgetTester tester, Type page) =>
    ModalRoute.of(tester.element(find.byType(page))) as NexoPageRoute<dynamic>;

void main() {
  const motion = NexoMotion.standardMotion;

  testWidgets('criar sobe; abrir algo existente vai no eixo X; Medium e '
      'Short', (tester) async {
    await _pump(tester);
    _router(tester).push(AppRoutes.newPlan);
    await tester.pumpAndSettle();
    final create = _topRoute(tester, CreatePlanPage);
    expect(create.motion, NexoPageMotion.slideUp);
    expect(create.transitionDuration, motion.medium);
    expect(create.reverseTransitionDuration, motion.short);
    // A tela de baixo não se move sob uma tela que sobe.
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();

    _router(tester).push(AppRoutes.profile);
    await tester.pump();
    await tester.pump(motion.short);
    final profile =
        ModalRoute.of(tester.element(find.byType(ProfilePage)))!
            as NexoPageRoute<dynamic>;
    expect(profile.motion, NexoPageMotion.sharedAxisX);
    await tester.pumpAndSettle();
  });

  testWidgets('reduzir movimento: duração zero nas telas e nas abas', (
    tester,
  ) async {
    await _pump(tester, reduceMotion: true);
    _router(tester).push(AppRoutes.newTask);
    await tester.pump();
    await tester.pump();
    expect(find.text('Nova tarefa'), findsOneWidget);
    final route =
        ModalRoute.of(tester.element(find.text('Nova tarefa')))!
            as NexoPageRoute<dynamic>;
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();

    // Troca de aba seca: a aba nova aparece no primeiro quadro.
    await tester.tap(find.byIcon(LucideIcons.listTodo));
    await tester.pump();
    expect(find.byType(TasksPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('troca de aba em fade through, mantendo o estado', (
    tester,
  ) async {
    await _pump(tester);
    final homeState = tester.state(find.byType(HomePage));
    await tester.tap(find.byIcon(LucideIcons.listTodo));
    await tester.pump();
    // No meio: as duas abas no palco (a que sai esmaecendo, a que entra
    // crescendo de Scale/Enter).
    await tester.pump(motion.medium * 0.5);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(TasksPage), findsOneWidget);
    final scales = tester
        .widgetList<Transform>(
          find.ancestor(
            of: find.byType(TasksPage),
            matching: find.byType(Transform),
          ),
        )
        .map((t) => t.transform.storage[0])
        .where((s) => s < 1);
    expect(scales, isNotEmpty);
    expect(scales.first, greaterThanOrEqualTo(motion.scaleEnter));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsNothing);

    // Volta ao Início: o mesmo estado (a aba não foi recriada).
    await tester.tap(find.byIcon(LucideIcons.house));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(HomePage)), same(homeState));
  });

  testWidgets('diálogo cresce de Scale/Enter e sai em Short', (tester) async {
    await _pump(tester);
    showNexoDialog(
      tester.element(find.byType(HomePage)),
      title: 'Excluir plano?',
      message: 'Teste.',
      confirmLabel: 'Excluir plano',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    double dialogScale() => tester
        .widget<Transform>(
          find
              .ancestor(
                of: find.byType(NexoDialog),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .storage[0];
    expect(dialogScale(), closeTo(motion.scaleEnter, 0.02));
    await tester.pumpAndSettle();
    final route =
        ModalRoute.of(tester.element(find.byType(NexoDialog)))!
            as TransitionRoute<dynamic>;
    expect(route.transitionDuration, motion.medium);
    expect(route.reverseTransitionDuration, motion.short);
    // Ao fechar, só esmaece: a escala fica em 1 (não encolhe).
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pump(motion.short * 0.5);
    expect(dialogScale(), 1);
    await tester.pumpAndSettle();
  });

  testWidgets('eixo X: Surface atrás da tela que sai (sem buraco aos 30%)', (
    tester,
  ) async {
    await _pump(tester);
    _router(tester).push(AppRoutes.profile);
    await tester.pump();
    await tester.pump(motion.medium * 0.35);
    final surface = NexoColors.light.surface;
    final fills = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where(
          (b) =>
              b.color.r == surface.r &&
              b.color.g == surface.g &&
              b.color.b == surface.b &&
              b.color.a > 0.9,
        );
    expect(fills, isNotEmpty);
    await tester.pumpAndSettle();
  });

  testWidgets('troca rápida de abas continua animada (A → B → C)', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byIcon(LucideIcons.listTodo));
    await tester.pump();
    await tester.pump(motion.medium * 0.2);
    await tester.tap(find.byIcon(LucideIcons.target).first);
    await tester.pump();
    await tester.pump(motion.medium * 0.2);
    // A aba de onde saiu (Tarefas) ainda esmaece: a troca nova não virou
    // corte seco.
    expect(find.byType(TasksPage), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(TasksPage), findsNothing);
  });

  testWidgets('passos do Criar plano: só o conteúdo desliza; voltar recua '
      'um passo', (tester) async {
    await _pump(tester);
    _router(tester).push(AppRoutes.newPlan);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Treino');
    await tester.tap(find.bySemanticsLabel('Fim'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NexoButton, 'Continuar'));
    await tester.pump();
    await tester.pump(motion.medium * 0.5);
    // No meio da troca, os dois passos na tela; o topo é um só.
    expect(find.text('Nome do plano'), findsOneWidget);
    expect(find.text('Frequência'), findsOneWidget);
    expect(find.text('Novo plano'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Nome do plano'), findsNothing);

    // Voltar do Android no passo 2: volta um passo, não fecha.
    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Passo 1 de 3 · O plano'), findsOneWidget);
    expect(find.byType(CreatePlanPage), findsOneWidget);
  });

  testWidgets('abrir e voltar de um detalhe não salta na vertical '
      '(plano, disciplina e tarefa)', (tester) async {
    await _pump(tester);
    final c = ProviderScope.containerOf(tester.element(find.byType(NexoApp)));
    await seedPlanHistory(c.read(plansRepositoryProvider));
    final subject = await c
        .read(subjectsRepositoryProvider)
        .createSubject(name: 'Cálculo II', icon: 'calculator');
    await c
        .read(tasksRepositoryProvider)
        .createTask(
          NexoTask(
            id: '',
            title: 'Lista de exercícios 3',
            subjectId: subject.id,
            dueAt: DateTime(2026, 11, 4, 18),
          ),
        );
    await tester.pumpAndSettle();

    /// A posição vertical de [watch] em cada quadro da transição (enquanto
    /// existir) não muda: só desliza na horizontal.
    Future<void> noJump(Finder tap, Finder watch) async {
      await tester.tap(tap);
      final ys = <double>{};
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final found = watch.evaluate();
        if (found.isNotEmpty) ys.add(tester.getTopLeft(watch.first).dy);
      }
      await tester.pumpAndSettle();
      expect(ys.length, lessThanOrEqualTo(1), reason: 'posições: $ys');
    }

    // Plano (dentro da aba Planos).
    await tester.tap(find.byIcon(LucideIcons.target).first);
    await tester.pumpAndSettle();
    final planTab = find.text('Visão geral');
    await noJump(find.text('Concurso Banco Horizonte'), planTab);
    await noJump(find.byTooltip('Voltar'), planTab);

    // Disciplina (dentro da aba Tarefas) e a lista dela.
    await tester.tap(find.byIcon(LucideIcons.listTodo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disciplinas'));
    await tester.pumpAndSettle();
    final segmented = find.text('Disciplinas');
    await noJump(find.text('Cálculo II'), find.text('Lista de exercícios 3'));
    await noJump(find.byTooltip('Voltar'), segmented);

    // Detalhe da tarefa (por cima das abas).
    await tester.tap(
      find.descendant(
        of: find.byType(TasksPage),
        matching: find.text('Tarefas'),
      ),
    );
    await tester.pumpAndSettle();
    await noJump(find.text('Lista de exercícios 3'), find.text('Título'));
    await noJump(find.byTooltip('Voltar'), find.text('Título'));
  });
}
