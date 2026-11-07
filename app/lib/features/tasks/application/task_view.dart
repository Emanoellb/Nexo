import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/local_flags.dart';

/// Visualização da aba Tarefas (botão "Visualização"), guardada no aparelho.
enum TaskView {
  /// Padrão: seções por prazo, recolhíveis.
  byDue('Por prazo'),

  /// Abas Hoje, Próximas e Concluídas.
  tabs('Hoje, Próximas e Concluídas');

  const TaskView(this.label);

  final String label;
}

class TaskViewNotifier extends Notifier<TaskView> {
  @override
  TaskView build() {
    final saved = ref.watch(localFlagsProvider).taskView;
    return TaskView.values.firstWhere(
      (v) => v.name == saved,
      orElse: () => TaskView.byDue,
    );
  }

  Future<void> set(TaskView view) async {
    state = view;
    await ref.read(localFlagsProvider).setTaskView(view.name);
  }
}

final taskViewProvider = NotifierProvider<TaskViewNotifier, TaskView>(
  TaskViewNotifier.new,
);
