import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/data/local_flags.dart';
import 'package:nexo/core/ui/ui.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/data/fake_auth_repository.dart';
import 'package:nexo/features/subjects/application/subjects_providers.dart';
import 'package:nexo/features/tasks/application/tasks_providers.dart';
import 'package:nexo/features/tasks/domain/task.dart';
import 'package:nexo/features/tasks/domain/task_rules.dart';
import 'package:nexo/features/tasks/presentation/task_form_page.dart';

import '../../helpers/screen_footer_checks.dart';

// Quarta, 04/11/2026, 10:00.
final _now = DateTime(2026, 11, 4, 10);

/// App logado, sem dados de exemplo, na aba Tarefas (360 × [height]).
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool dark = false,
  double height = 1200,
  double textScale = 1,
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
  await tester.tap(find.byIcon(LucideIcons.listTodo));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(NexoApp)));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.widgetWithText(NexoButton, label);

Future<List<NexoTask>> _tasks(ProviderContainer c) =>
    c.read(tasksRepositoryProvider).watchTasks().first;

Future<void> _openNew(WidgetTester tester) async {
  await _tap(tester, find.byType(NexoFab));
  await _tap(tester, find.text('Nova tarefa'));
  expect(find.byType(TaskFormPage), findsOneWidget);
}

/// Toca no campo pelo rótulo do leitor de tela (o `NexoSelectField`).
Finder _field(String label) => find.bySemanticsLabel(label);

void main() {
  testWidgets('Nova tarefa: título em branco avisa; criar fecha e confirma', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final c = await _pump(tester);
    await _openNew(tester);
    expect(find.byTooltip('Fechar'), findsOneWidget);
    expect(find.text('Sem disciplina'), findsOneWidget);
    expect(find.text('Sem prazo'), findsOneWidget);
    expect(find.text('Sem situação'), findsOneWidget);
    // Sem prazo, sem avisos.
    expect(find.text('Avisos de entrega'), findsNothing);
    // Formulário sem títulos de grupo.
    expect(find.text('Quando'), findsNothing);
    expect(find.text('Como está'), findsNothing);

    await _tap(tester, _button('Criar tarefa'));
    expect(find.text('Dê um título à tarefa.'), findsOneWidget);
    expect(await _tasks(c), isEmpty);

    await tester.enterText(find.byType(TextField), 'Lista de exercícios 4');
    await tester.pump();
    expect(find.text('Dê um título à tarefa.'), findsNothing);
    await _tap(tester, _button('Criar tarefa'));
    expect(find.byType(TaskFormPage), findsNothing);
    expect(find.text('Tarefa criada.'), findsOneWidget);
    final task = (await _tasks(c)).single;
    expect(task.title, 'Lista de exercícios 4');
    expect(task.dueAt, isNull);
    expect(task.remindersMinutesBefore, isEmpty);
    handle.dispose();
  });

  testWidgets('Nova tarefa: rodapé livre da Snackbar e do teclado', (
    tester,
  ) async {
    await _pump(tester);
    await _openNew(tester);
    await expectFooterClearOfSnackbarAndKeyboard(
      tester,
      page: find.byType(TaskFormPage),
      footerButton: _button('Criar tarefa'),
    );
  });

  testWidgets('prazo sugere "1 dia"; até 3 avisos, sem repetir; sem prazo '
      'esvazia', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await _pump(tester);
    await _openNew(tester);
    await tester.enterText(find.byType(TextField), 'Trabalho de modelagem');

    // Escolher o prazo (hoje, no calendário): o aviso já vem em 1 dia.
    await _tap(tester, _field('Prazo'));
    await _tap(tester, find.text('OK'));
    expect(find.text('Hoje, 04/11/2026'), findsOneWidget);
    expect(find.text('1 dia'), findsOneWidget);
    expect(find.text('Antes do prazo · até 3 avisos.'), findsOneWidget);

    // "1 dia antes" já marcado não duplica; "1 hora antes" entra.
    await _tap(tester, _button('Adicionar aviso'));
    await _tap(tester, find.text('1 dia antes'));
    expect(find.text('1 dia'), findsOneWidget);
    await _tap(tester, _button('Adicionar aviso'));
    await _tap(tester, find.text('1 hora antes'));
    expect(find.text('1 hora'), findsOneWidget);

    // Personalizado: acima de 30 dias não entra; 2 dias entra.
    await _tap(tester, _button('Adicionar aviso'));
    await _tap(tester, find.text('Personalizado…'));
    expect(find.text('Novo aviso'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(NexoBottomSheet),
        matching: find.byType(TextField),
      ),
      '31',
    );
    await _tap(tester, _button('Aplicar'));
    expect(find.text('Escolha até 30 dias antes.'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(NexoBottomSheet),
        matching: find.byType(TextField),
      ),
      '2',
    );
    await _tap(tester, _button('Aplicar'));
    expect(find.text('2 dias'), findsOneWidget);

    // Com 3, o botão some e o texto avisa.
    expect(_button('Adicionar aviso'), findsNothing);
    expect(find.text('Máximo de 3 avisos.'), findsOneWidget);

    // Remover pelo X.
    await _tap(tester, find.bySemanticsLabel('Remover aviso de 1 hora'));
    expect(find.text('1 hora'), findsNothing);
    expect(_button('Adicionar aviso'), findsOneWidget);

    await _tap(tester, _button('Criar tarefa'));
    final task = (await _tasks(c)).single;
    // Sem hora, vale 23:59.
    expect(task.dueAt, DateTime(2026, 11, 4, 23, 59));
    expect(task.remindersMinutesBefore, [2880, TaskReminder.oneDay]);
    handle.dispose();
  });

  testWidgets('tirar o prazo tira os avisos', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    await _openNew(tester);
    await _tap(tester, _field('Prazo'));
    await _tap(tester, find.text('OK'));
    expect(find.text('1 dia'), findsOneWidget);
    await _tap(tester, _field('Prazo'));
    await _tap(tester, find.text('Sem prazo').last);
    expect(find.text('1 dia'), findsNothing);
    expect(find.text('Avisos de entrega'), findsNothing);
    handle.dispose();
  });

  group('detalhe', () {
    Future<(ProviderContainer, NexoTask)> openDetail(
      WidgetTester tester, {
      DateTime? due,
      bool completed = false,
      bool dark = false,
      double textScale = 1,
    }) async {
      final c = await _pump(tester, dark: dark, textScale: textScale);
      final subject = await c
          .read(subjectsRepositoryProvider)
          .createSubject(name: 'Banco de Dados', icon: 'database');
      final repo = c.read(tasksRepositoryProvider);
      var task = await repo.createTask(
        NexoTask(
          id: '',
          title: 'Trabalho de modelagem do banco',
          subjectId: subject.id,
          dueAt: due ?? DateTime(2026, 11, 4, 18),
          remindersMinutesBefore: const [10080, 2880, 1440],
          deliveryStatus: DeliveryStatus.inProgress,
        ),
      );
      if (completed) await repo.setCompleted(task.id, true);
      task = (await _tasks(c)).single;
      await tester.pumpAndSettle();
      // A seção Concluídas começa recolhida.
      if (completed) await _tap(tester, find.text('Concluídas'));
      await _tap(tester, find.text('Trabalho de modelagem do banco'));
      expect(find.byType(TaskFormPage), findsOneWidget);
      return (c, task);
    }

    testWidgets('pendente: resumo, 3 avisos e "Marcar como concluída"', (
      tester,
    ) async {
      final (c, _) = await openDetail(tester);
      expect(find.text('Tarefa'), findsOneWidget);
      expect(find.text('Prazo hoje, 18:00'), findsOneWidget);
      expect(find.byIcon(LucideIcons.circleDot), findsWidgets);
      expect(find.text('Banco de Dados'), findsOneWidget);
      expect(find.text('Em andamento'), findsOneWidget);
      for (final chip in ['1 semana', '2 dias', '1 dia']) {
        expect(find.text(chip), findsOneWidget);
      }
      expect(find.text('Máximo de 3 avisos.'), findsOneWidget);
      expect(_button('Salvar'), findsNothing);

      // Concluir: +1 ponto e "Entregue" no mesmo gravar; vira "Reabrir".
      await _tap(tester, _button('Marcar como concluída'));
      expect(find.text('Tarefa concluída. +1 ponto'), findsOneWidget);
      expect(_button('Reabrir tarefa'), findsOneWidget);
      expect(find.text('Entregue'), findsOneWidget);
      expect(find.text('Avisos desligados: tarefa concluída.'), findsOneWidget);
      expect((await _tasks(c)).single.completed, isTrue);
    });

    testWidgets('detalhe: rodapé livre da Snackbar e do teclado', (
      tester,
    ) async {
      await openDetail(tester);
      await expectFooterClearOfSnackbarAndKeyboard(
        tester,
        page: find.byType(TaskFormPage),
        footerButton: _button('Marcar como concluída'),
      );
    });

    testWidgets('mudar vira "Salvar"; voltar pergunta; salvar grava', (
      tester,
    ) async {
      final (c, _) = await openDetail(tester);
      await _tap(tester, find.text('Alta'));
      expect(_button('Salvar'), findsOneWidget);
      expect(_button('Marcar como concluída'), findsNothing);

      await _tap(tester, find.byTooltip('Voltar'));
      expect(find.text('Descartar alterações?'), findsOneWidget);
      expect(
        find.text('As mudanças nesta tarefa não serão salvas.'),
        findsOneWidget,
      );
      await _tap(tester, find.text('Continuar editando'));
      expect(find.byType(TaskFormPage), findsOneWidget);

      await _tap(tester, _button('Salvar'));
      expect(find.text('Alterações salvas.'), findsOneWidget);
      expect(_button('Marcar como concluída'), findsOneWidget);
      expect((await _tasks(c)).single.priority, TaskPriority.high);

      // Descartar sai sem gravar.
      await _tap(tester, find.text('Baixa'));
      await _tap(tester, find.byTooltip('Voltar'));
      await _tap(tester, _button('Descartar'));
      expect(find.byType(TaskFormPage), findsNothing);
      expect((await _tasks(c)).single.priority, TaskPriority.high);
    });

    testWidgets('atrasada: o texto em Error no resumo e abaixo do prazo', (
      tester,
    ) async {
      await openDetail(tester, due: DateTime(2026, 11, 3, 23, 59));
      expect(find.text('Atrasada · venceu ontem, 23:59'), findsNWidgets(2));
    });

    testWidgets('concluída: "Reabrir tarefa" devolve a pendente', (
      tester,
    ) async {
      final (c, _) = await openDetail(tester, completed: true);
      expect(find.text('Concluída em qua, 04/11'), findsOneWidget);
      expect(_button('Adicionar aviso'), findsNothing);
      await _tap(tester, _button('Reabrir tarefa'));
      expect(find.text('Tarefa reaberta. −1 ponto'), findsOneWidget);
      final task = (await _tasks(c)).single;
      expect(task.completed, isFalse);
      expect(task.deliveryStatus, DeliveryStatus.inProgress);
    });

    testWidgets('⋯ só exclui: fecha e mostra "Desfazer"', (tester) async {
      final (c, _) = await openDetail(tester);
      await _tap(tester, find.byTooltip('Mais opções'));
      expect(find.text('Excluir tarefa'), findsOneWidget);
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Duplicar'), findsNothing);
      await _tap(tester, find.text('Excluir tarefa'));
      expect(find.byType(TaskFormPage), findsNothing);
      expect(find.text('Tarefa excluída.'), findsOneWidget);
      await _tap(tester, find.text('Desfazer'));
      expect(await _tasks(c), hasLength(1));
      expect(find.text('Trabalho de modelagem do banco'), findsOneWidget);
    });

    for (final dark in [false, true]) {
      testWidgets('acessibilidade e fonte 2,0 (${dark ? 'escuro' : 'claro'})', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await openDetail(tester, dark: dark, textScale: 2);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });
}
