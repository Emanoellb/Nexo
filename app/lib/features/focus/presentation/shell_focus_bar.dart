import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/data/clock.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../plans/application/plans_providers.dart';
import '../../plans/application/topic_actions.dart';
import '../application/focus_controller.dart';

/// Onde a Barra do foco está: a tela do foco encolhe até aqui ao minimizar
/// (`NexoPageMotion.focus`).
final focusBarKey = GlobalKey(debugLabel: 'Barra do foco');

/// A Barra do foco nas abas (telas 13 e 14): aparece com um foco em
/// andamento ou pausado, acima da barra de abas, em todas as abas. Tocar
/// reabre o foco; o botão pausa ou retoma. Coberta por outra tela, some e
/// volta esmaecendo no fim da saída dela.
class ShellFocusBar extends ConsumerWidget {
  const ShellFocusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(activeFocusProvider);
    if (focus == null) return const SizedBox.shrink();
    final now = ref.watch(focusNowProvider).value ?? ref.read(clockProvider)();
    final plan = ref.watch(planProvider(focus.planId)).value;
    final topics = {
      for (final t
          in ref.watch(visibleTopicsProvider(focus.planId)).value ?? const [])
        t.id: t.name,
    };
    final detail = [
      plan?.name ?? 'Foco',
      for (final id in focus.topicIds)
        if (topics[id] != null) topics[id]!,
    ].join(' · ');
    final notifier = ref.read(activeFocusProvider.notifier);
    final spacing = context.spacing;

    final bar = NexoFocusBar(
      time: formatClock(focus.elapsed(now)),
      detail: detail,
      paused: focus.isPaused,
      onOpen: () => context.push(AppRoutes.focus),
      onToggle: focus.isPaused ? notifier.resume : notifier.pause,
    );

    // Coberta por outra tela (o próprio foco, um detalhe): some; volta no
    // fim da saída dessa tela. Ao minimizar, a tela do foco encolhe até
    // este lugar ([focusBarKey]) e a barra aparece no fim.
    final covered = ModalRoute.of(context)?.secondaryAnimation;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.lg),
      child: KeyedSubtree(
        key: focusBarKey,
        child: covered == null || reduce
            ? bar
            : AnimatedBuilder(
                animation: covered,
                builder: (context, child) => Opacity(
                  opacity: const Interval(0.7, 1).transform(1 - covered.value),
                  child: child,
                ),
                child: bar,
              ),
      ),
    );
  }
}
