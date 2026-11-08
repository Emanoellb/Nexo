import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/data/local_flags.dart';
import 'package:nexo/core/ui/ui.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/data/fake_auth_repository.dart';
import 'package:nexo/features/home/presentation/home_page.dart';
import 'package:nexo/features/subjects/application/subjects_providers.dart';
import 'package:nexo/features/subjects/data/subjects_repository.dart';
import 'package:nexo/features/subjects/domain/subject.dart';
import 'package:nexo/features/subjects/presentation/subject_detail_page.dart';
import 'package:nexo/features/tasks/application/tasks_providers.dart';
import 'package:nexo/features/tasks/domain/task.dart';
import 'package:nexo/features/tasks/presentation/tasks_page.dart';

// Quarta, 04/11/2026, 10:00.
var _now = DateTime(2026, 11, 4, 10);

/// App logado na conta de protótipo, sem dados de exemplo, já na aba
/// Tarefas. Padrão: 360 × 1200 (as seções cabem sem rolar); [phone], 360 ×
/// 800.
Future<(ProviderContainer, InMemoryLocalFlags)> _pumpTasks(
  WidgetTester tester, {
  bool dark = false,
  String? taskView,
  bool phone = false,
  List<Override> overrides = const [],
}) async {
  _now = DateTime(2026, 11, 4, 10);
  tester.view.physicalSize = Size(1080, phone ? 2400 : 3600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final flags = InMemoryLocalFlags(
    firstOpenDone: true,
    themePreference: dark ? 'dark' : 'light',
    taskView: taskView,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
        clockProvider.overrideWithValue(() => _now),
        localFlagsProvider.overrideWithValue(flags),
        ...overrides,
      ],
      child: const NexoApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(LucideIcons.listTodo));
  await tester.pumpAndSettle();
  final c = ProviderScope.containerOf(tester.element(find.byType(NexoApp)));
  return (c, flags);
}

/// Disciplinas que não salvam (ex.: sem conexão, na integração).
class _FailingSubjects extends FakeSubjectsRepository {
  @override
  Future<Subject> createSubject({required String name, required String icon}) =>
      Future.error(StateError('sem conexão'));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Duas disciplinas e tarefas em todas as seções (como no design).
Future<({Subject calc, Subject db})> _seed(ProviderContainer c) async {
  final subjects = c.read(subjectsRepositoryProvider);
  final calc = await subjects.createSubject(
    name: 'Cálculo II',
    icon: 'calculator',
  );
  final db = await subjects.createSubject(
    name: 'Banco de Dados',
    icon: 'database',
  );
  final tasks = c.read(tasksRepositoryProvider);
  for (final (title, due, subject, priority) in [
    ('Lista de exercícios 3', DateTime(2026, 11, 3, 23, 59), calc.id, false),
    ('Trabalho de modelagem', DateTime(2026, 11, 4, 18), db.id, true),
    ('Resumo do capítulo 2', DateTime(2026, 11, 4, 21), calc.id, false),
    ('Relatório de laboratório', DateTime(2026, 11, 5, 18), null, false),
    (
      'Entrega do relatório parcial',
      DateTime(2026, 11, 5 + 1, 23, 59),
      db.id,
      false,
    ),
    ('Ler capítulo 4', null, db.id, false),
  ]) {
    await tasks.createTask(
      NexoTask(
        id: '',
        title: title,
        dueAt: due,
        subjectId: subject,
        priority: priority ? TaskPriority.high : TaskPriority.none,
      ),
    );
  }
  // Concluída ontem.
  final done = await tasks.createTask(
    NexoTask(id: '', title: 'Lista de exercícios 2', subjectId: calc.id),
  );
  _now = DateTime(2026, 11, 3, 20);
  await tasks.setCompleted(done.id, true);
  _now = DateTime(2026, 11, 4, 10);
  return (calc: calc, db: db);
}

Future<List<NexoTask>> _tasks(ProviderContainer c) =>
    c.read(tasksRepositoryProvider).watchTasks().first;

void main() {
  testWidgets('vazio: sem chips, sem filtros e "Criar uma tarefa"', (
    tester,
  ) async {
    await _pumpTasks(tester);
    expect(find.byType(TasksPage), findsOneWidget);
    expect(find.text('Suas tarefas aparecem aqui'), findsOneWidget);
    expect(
      find.text(
        'Crie tarefas com prazo, prioridade e disciplina. Elas também '
        'aparecem no Início e na Agenda.',
      ),
      findsOneWidget,
    );
    expect(find.byType(NexoFilterChip), findsNothing);
    // Sem tarefas, o botão de filtros não aparece.
    expect(find.byTooltip('Visualização'), findsNothing);

    await _tap(tester, find.text('Criar uma tarefa'));
    expect(find.text('Nova tarefa'), findsOneWidget);
    expect(find.byTooltip('Fechar'), findsOneWidget);
  });

  testWidgets('por prazo: seções na ordem, Concluídas recolhida', (
    tester,
  ) async {
    final (c, _) = await _pumpTasks(tester);
    await _seed(c);
    await tester.pumpAndSettle();

    final headers = [
      'Atrasadas',
      'Hoje',
      'Amanhã',
      'Esta semana',
      'Sem prazo',
      'Concluídas',
    ];
    final ys = [
      for (final h in headers) tester.getTopLeft(find.text(h).last).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(find.text('Depois'), findsNothing);
    expect(find.text('Atrasada · ontem, 23:59'), findsOneWidget);
    expect(find.text('Hoje · 18:00'), findsOneWidget);
    // Concluídas começa recolhida; o cabeçalho inteiro abre.
    expect(find.text('Lista de exercícios 2'), findsNothing);
    await _tap(tester, find.bySemanticsLabel('Concluídas, 1'));
    expect(find.text('Lista de exercícios 2'), findsOneWidget);
    expect(find.text('Concluída ontem'), findsOneWidget);
    // E recolhe de novo.
    await _tap(tester, find.bySemanticsLabel('Hoje, 2'));
    expect(find.text('Resumo do capítulo 2'), findsNothing);
  });

  testWidgets('chips filtram; sem resultado, "Mostrar todas" volta', (
    tester,
  ) async {
    final (c, _) = await _pumpTasks(tester, taskView: 'tabs');
    final s = await _seed(c);
    await tester.pumpAndSettle();
    expect(find.text('Todas'), findsOneWidget);

    await _tap(tester, find.widgetWithText(NexoFilterChip, 'Cálculo II'));
    // Hoje: a atrasada no topo e a de hoje de Cálculo II.
    expect(find.text('Lista de exercícios 3'), findsOneWidget);
    expect(find.text('Resumo do capítulo 2'), findsOneWidget);
    expect(find.text('Trabalho de modelagem'), findsNothing);

    // Nada de Cálculo II nas próximas.
    await _tap(tester, find.textContaining('Próximas'));
    expect(find.text('Nada de Cálculo II nas próximas'), findsOneWidget);
    expect(
      find.text('As tarefas de Cálculo II de amanhã em diante aparecem aqui.'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Mostrar todas'));
    expect(find.text('Relatório de laboratório'), findsOneWidget);
    expect(s.calc.name, 'Cálculo II');
  });

  testWidgets('visualização: menu, abas com contagem, ponto e escolha salva', (
    tester,
  ) async {
    final (c, flags) = await _pumpTasks(tester);
    expect(find.byTooltip('Visualização'), findsNothing);
    await _seed(c);
    await tester.pumpAndSettle();
    // Com a primeira tarefa, o botão de filtros aparece.
    expect(find.byTooltip('Visualização'), findsOneWidget);
    expect(find.byType(NexoTabs), findsNothing);

    await _tap(tester, find.byTooltip('Visualização'));
    expect(find.text('Por prazo'), findsOneWidget);
    await _tap(tester, find.text('Hoje, Próximas e Concluídas'));
    expect(find.byType(NexoTabs), findsOneWidget);
    expect(flags.taskView, 'tabs');
    // Hoje: 1 atrasada + 2 de hoje; Próximas: amanhã, quinta e sem prazo.
    expect(find.bySemanticsLabel('Hoje, 3, aba 1 de 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Próximas, 3, aba 2 de 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Concluídas, 1, aba 3 de 3'), findsOneWidget);
  });

  testWidgets('deslizar à direita conclui (+1 ponto) e "Desfazer" reabre', (
    tester,
  ) async {
    final (c, _) = await _pumpTasks(tester);
    await _seed(c);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Resumo do capítulo 2'), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(find.text('Tarefa concluída. +1 ponto'), findsOneWidget);
    var task = (await _tasks(c))
        .firstWhere((t) => t.title.startsWith('Resumo'));
    expect(task.completed, isTrue);

    await _tap(tester, find.text('Desfazer'));
    task = (await _tasks(c)).firstWhere((t) => t.title.startsWith('Resumo'));
    expect(task.completed, isFalse);
  });

  testWidgets('deslizar à esquerda: Adiar vai para amanhã, mesmo horário', (
    tester,
  ) async {
    final (c, _) = await _pumpTasks(tester);
    await _seed(c);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Resumo do capítulo 2'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await _tap(tester, find.bySemanticsLabel('Adiar').last);
    expect(find.text('Tarefa adiada para amanhã.'), findsOneWidget);
    var task = (await _tasks(c))
        .firstWhere((t) => t.title.startsWith('Resumo'));
    expect(task.dueAt, DateTime(2026, 11, 5, 21));

    await _tap(tester, find.text('Desfazer'));
    task = (await _tasks(c)).firstWhere((t) => t.title.startsWith('Resumo'));
    expect(task.dueAt, DateTime(2026, 11, 4, 21));
  });

  testWidgets('Excluir sem confirmação: some na hora, apaga ao fim do aviso', (
    tester,
  ) async {
    final (c, _) = await _pumpTasks(tester);
    await _seed(c);
    await tester.pumpAndSettle();

    // Desfazer: volta e não apaga.
    await tester.drag(find.text('Resumo do capítulo 2'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await _tap(tester, find.bySemanticsLabel('Excluir').last);
    expect(find.text('Resumo do capítulo 2'), findsNothing);
    expect(find.text('Tarefa excluída.'), findsOneWidget);
    await _tap(tester, find.text('Desfazer'));
    expect(find.text('Resumo do capítulo 2'), findsOneWidget);
    expect((await _tasks(c)).length, 7);

    // Sem tocar: apaga quando o aviso some.
    await tester.drag(find.text('Resumo do capítulo 2'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await _tap(tester, find.bySemanticsLabel('Excluir').last);
    expect((await _tasks(c)).length, 7);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect((await _tasks(c)).length, 6);
    expect(find.text('Resumo do capítulo 2'), findsNothing);
  });

  testWidgets('toque longo mostra as mesmas ações; toque abre o detalhe', (
    tester,
  ) async {
    final (c, _) = await _pumpTasks(tester);
    await _seed(c);
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Resumo do capítulo 2'));
    await tester.pumpAndSettle();
    expect(find.text('Concluir'), findsOneWidget);
    expect(find.text('Adiar para amanhã'), findsOneWidget);
    expect(find.text('Excluir'), findsOneWidget);
    await _tap(tester, find.text('Concluir'));
    expect(find.text('Tarefa concluída. +1 ponto'), findsOneWidget);

    // Sem prazo, ou com prazo de amanhã em diante, não tem Adiar (não
    // adianta o prazo).
    for (final title in ['Ler capítulo 4', 'Relatório de laboratório']) {
      await tester.longPress(find.text(title));
      await tester.pumpAndSettle();
      expect(find.text('Adiar para amanhã'), findsNothing);
      expect(find.text('Excluir'), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
    }
    await tester.drag(
      find.text('Relatório de laboratório'),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Adiar'), findsNothing);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Ler capítulo 4'));
    expect(find.text('Tarefa'), findsOneWidget);
    expect(find.text('Sem prazo'), findsWidgets);
  });

  testWidgets('excluída some também do Início enquanto o aviso dura', (
    tester,
  ) async {
    final (c, _) = await _pumpTasks(tester);
    await _seed(c);
    await tester.pumpAndSettle();
    await tester.drag(find.text('Resumo do capítulo 2'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await _tap(tester, find.bySemanticsLabel('Excluir').last);

    await tester.tap(find.byIcon(LucideIcons.house));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Trabalho de modelagem'), findsOneWidget);
    expect(find.text('Resumo do capítulo 2'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('no horário do prazo, a tarefa vira "Atrasada" sozinha', (
    tester,
  ) async {
    final (c, _) = await _pumpTasks(tester);
    await _seed(c);
    await tester.pumpAndSettle();
    expect(find.text('Hoje · 18:00'), findsOneWidget);

    // 18:00:02: o timer da tela renova o "agora" no próximo prazo.
    _now = DateTime(2026, 11, 4, 18, 0, 2);
    await tester.pump(const Duration(hours: 8, seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Atrasada · hoje, 18:00'), findsOneWidget);
    expect(find.text('Hoje · 18:00'), findsNothing);
  });

  group('disciplinas', () {
    testWidgets('falha ao salvar: avisa no campo e deixa tentar de novo', (
      tester,
    ) async {
      await _pumpTasks(
        tester,
        overrides: [
          subjectsRepositoryProvider.overrideWithValue(_FailingSubjects()),
        ],
      );
      await _tap(tester, find.text('Disciplinas'));
      await _tap(tester, find.text('Adicionar disciplina'));
      await tester.enterText(find.byType(TextField), 'Física');
      await tester.pumpAndSettle();
      final save = find.widgetWithText(NexoButton, 'Salvar disciplina');
      await _tap(tester, save);
      expect(find.text('Nova disciplina'), findsOneWidget);
      expect(
        find.text('Não foi possível salvar. Tente de novo.'),
        findsOneWidget,
      );
      expect(tester.widget<NexoButton>(save).onPressed, isNotNull);
    });

    testWidgets('vazio e cadastro: nome obrigatório, sem repetir, 12 ícones', (
      tester,
    ) async {
      final (c, _) = await _pumpTasks(tester);
      await _tap(tester, find.text('Disciplinas'));
      expect(find.text('Adicione suas disciplinas'), findsOneWidget);
      expect(
        find.text(
          'Organize tarefas, provas e trabalhos pelas disciplinas que você '
          'está cursando.',
        ),
        findsOneWidget,
      );

      await _tap(tester, find.text('Adicionar disciplina'));
      expect(find.text('Nova disciplina'), findsOneWidget);
      final save = find.widgetWithText(NexoButton, 'Salvar disciplina');
      expect(tester.widget<NexoButton>(save).onPressed, isNull);
      expect(find.bySemanticsLabel(RegExp('^Ícone ')), findsNWidgets(12));

      await tester.enterText(find.byType(TextField), 'Física');
      await tester.pumpAndSettle();
      await _tap(tester, find.bySemanticsLabel('Ícone Átomo'));
      await _tap(tester, save);
      final subjects = await c
          .read(subjectsRepositoryProvider)
          .watchSubjects()
          .first;
      expect(subjects.single.name, 'Física');
      expect(subjects.single.icon, 'atom');
      expect(find.text('Disciplina criada.'), findsOneWidget);
      expect(find.text('0 de 0 entregas'), findsOneWidget);

      // Repetido (sem acento e sem maiúsculas).
      await _tap(tester, find.text('Adicionar disciplina'));
      await tester.enterText(find.byType(TextField), 'fisica');
      await tester.pumpAndSettle();
      expect(
        find.text('Você já tem uma disciplina com esse nome.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<NexoButton>(
              find.widgetWithText(NexoButton, 'Salvar disciplina'),
            )
            .onPressed,
        isNull,
      );
      // Apagar tudo mostra o erro de obrigatório.
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('Informe o nome da disciplina.'), findsOneWidget);
    });

    testWidgets('lista em ordem alfabética, progresso e próxima entrega', (
      tester,
    ) async {
      final (c, _) = await _pumpTasks(tester);
      await _seed(c);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Disciplinas'));

      expect(
        tester.getTopLeft(find.text('Banco de Dados')).dy,
        lessThan(tester.getTopLeft(find.text('Cálculo II')).dy),
      );
      expect(find.text('1 de 3 entregas'), findsOneWidget);
      // Lib: título à esquerda e contagem à direita (na fonte de teste, mais
      // larga, a contagem desce de linha; confere-se o alinhamento).
      expect(
        tester
            .widget<Wrap>(
              find.ancestor(
                of: find.text('1 de 3 entregas'),
                matching: find.byType(Wrap),
              ),
            )
            .alignment,
        WrapAlignment.spaceBetween,
      );
      expect(
        find.text('Próxima: Lista de exercícios 3 · atrasada'),
        findsOneWidget,
      );
      expect(
        find.text('Próxima: Trabalho de modelagem · hoje'),
        findsOneWidget,
      );
    });

    testWidgets('detalhe: só as tarefas dela; excluir mantém as tarefas', (
      tester,
    ) async {
      final (c, _) = await _pumpTasks(tester);
      final s = await _seed(c);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Disciplinas'));
      await _tap(tester, find.text('Cálculo II'));

      expect(find.byType(SubjectDetailPage), findsOneWidget);
      expect(find.text('Entregas'), findsOneWidget);

      // Voltar do aparelho no detalhe: volta para a lista, não para o Início.
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.byType(SubjectDetailPage), findsNothing);
      expect(find.byType(TasksPage), findsOneWidget);
      await _tap(tester, find.text('Cálculo II'));
      expect(find.byType(SubjectDetailPage), findsOneWidget);
      expect(find.text('Lista de exercícios 3'), findsOneWidget);
      expect(find.text('Trabalho de modelagem'), findsNothing);
      // A barra de baixo continua.
      expect(find.byType(NexoBottomBar), findsOneWidget);

      // Pede confirmação; "Cancelar" não exclui.
      await _tap(tester, find.byTooltip('Mais opções'));
      await _tap(tester, find.text('Excluir disciplina'));
      expect(find.text('Excluir disciplina?'), findsOneWidget);
      expect(
        find.text(
          '"Cálculo II" sai da sua lista. As tarefas dela continuam no app, '
          'sem disciplina.',
        ),
        findsOneWidget,
      );
      await _tap(tester, find.text('Cancelar'));
      expect(find.byType(SubjectDetailPage), findsOneWidget);
      expect(find.text('Disciplina excluída.'), findsNothing);

      await _tap(tester, find.byTooltip('Mais opções'));
      await _tap(tester, find.text('Excluir disciplina'));
      await _tap(tester, find.widgetWithText(NexoButton, 'Excluir disciplina'));
      expect(find.byType(SubjectDetailPage), findsNothing);
      expect(find.text('Disciplina excluída.'), findsOneWidget);
      expect(find.text('Cálculo II'), findsNothing);

      await tester.pumpAndSettle(const Duration(seconds: 5));
      final subjects = await c
          .read(subjectsRepositoryProvider)
          .watchSubjects()
          .first;
      expect(subjects.map((x) => x.id), isNot(contains(s.calc.id)));
      // As tarefas continuam, sem disciplina.
      final tasks = await _tasks(c);
      expect(tasks.length, 7);
      expect(tasks.where((t) => t.subjectId == s.calc.id), isEmpty);
    });

    testWidgets('editar pelo menu e "Desfazer" da exclusão', (tester) async {
      final (c, _) = await _pumpTasks(tester);
      await _seed(c);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Disciplinas'));
      await _tap(tester, find.text('Cálculo II'));

      await _tap(tester, find.byTooltip('Mais opções'));
      await _tap(tester, find.text('Editar disciplina'));
      expect(find.text('Salvar alterações'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Cálculo III');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Salvar alterações'));
      expect(find.text('Cálculo III'), findsWidgets);

      await _tap(tester, find.byTooltip('Mais opções'));
      await _tap(tester, find.text('Editar disciplina'));
      await _tap(tester, find.text('Excluir disciplina'));
      // Pelo painel de edição também confirma.
      expect(find.text('Excluir disciplina?'), findsOneWidget);
      await _tap(tester, find.widgetWithText(NexoButton, 'Excluir disciplina'));
      expect(find.text('Disciplina excluída.'), findsOneWidget);
      await _tap(tester, find.text('Desfazer'));
      expect(find.text('Cálculo III'), findsOneWidget);
      final subjects = await c
          .read(subjectsRepositoryProvider)
          .watchSubjects()
          .first;
      expect(subjects.length, 2);
    });
  });

  for (final dark in [false, true]) {
    testWidgets(
      'diretrizes de alvo, rótulo e contraste (${dark ? 'escuro' : 'claro'})',
      (tester) async {
        final handle = tester.ensureSemantics();
        final (c, _) = await _pumpTasks(tester, dark: dark);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await _seed(c);
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await _tap(tester, find.text('Disciplinas'));
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
      final (c, _) = await _pumpTasks(tester, taskView: 'tabs', phone: true);
      await _seed(c);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _tap(tester, find.text('Disciplinas'));
      expect(tester.takeException(), isNull);
    });
  }
}
