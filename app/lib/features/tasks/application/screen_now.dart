import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../domain/task.dart';

/// O "agora" das telas com prazo (Início, Tarefas, disciplina): fixo entre
/// renovações, para todos os cálculos de uma tela usarem o mesmo instante.
/// Quem mostra prazos usa [ScreenNowRefresh] para renová-lo na hora certa.
final screenNowProvider = Provider<DateTime>(
  (ref) => ref.watch(clockProvider)(),
);

/// O próximo instante em que uma tela com estas tarefas precisa se
/// recalcular: a meia-noite ou o prazo pendente mais próximo (vira
/// "Atrasada"), o que vier antes.
DateTime nextNowRefresh(DateTime now, Iterable<NexoTask> tasks) {
  var next = DateTime(now.year, now.month, now.day + 1);
  for (final task in tasks) {
    final due = task.dueAt;
    if (task.completed || due == null || !due.isAfter(now)) continue;
    if (due.isBefore(next)) next = due;
  }
  return next;
}

/// Renova o [screenNowProvider] à meia-noite e no próximo prazo das tarefas
/// que a tela mostra. Chame [scheduleNowRefresh] no `build`.
mixin ScreenNowRefresh<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Timer? _nowTimer;
  DateTime? _nowAt;

  void scheduleNowRefresh(Iterable<NexoTask> tasks) {
    final now = ref.read(screenNowProvider);
    final at = nextNowRefresh(now, tasks);
    if (at == _nowAt) return;
    _nowAt = at;
    _nowTimer?.cancel();
    // +1 s: já do outro lado da virada.
    _nowTimer = Timer(at.difference(now) + const Duration(seconds: 1), () {
      if (mounted) ref.invalidate(screenNowProvider);
    });
  }

  @override
  void dispose() {
    _nowTimer?.cancel();
    super.dispose();
  }
}
