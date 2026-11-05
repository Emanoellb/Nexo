import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';
import 'nexo_fab.dart';

/// Uma opção do [showNexoFabMenu].
@immutable
class NexoFabMenuOption {
  const NexoFabMenuOption({
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
}

/// `Actions/FABMenu` da lib (FAB menu do M3, aprovado em 04/11/2026): as
/// opções sobem empilhadas acima do "+", alinhadas à direita, e o "+" vira X
/// ("Fechar menu"). Não escurece a tela. Fecha pelo X, pelo voltar, com toque
/// fora ou ao escolher; o foco volta ao "+". Entrada em sequência
/// (`Motion/Duration/Medium` + `Enter`), sem movimento com "reduzir
/// movimento".
///
/// [fabRect] é a posição do "+" na tela, para o X ficar no mesmo lugar.
Future<void> showNexoFabMenu(
  BuildContext context, {
  required Rect fabRect,
  required List<NexoFabMenuOption> options,
}) {
  final c = context.nexoColors;
  final motion = context.motion;
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  final screen = MediaQuery.sizeOf(context);
  final spacing = context.spacing;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar menu',
    // Sem escurecer a tela.
    barrierColor: c.scrim.withValues(alpha: 0),
    transitionDuration: reduceMotion ? Duration.zero : motion.medium,
    pageBuilder: (context, animation, _) => Stack(
      children: [
        Positioned(
          right: screen.width - fabRect.right,
          bottom: screen.height - fabRect.bottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                _Entering(
                  animation: animation,
                  // A opção mais perto do "+" entra primeiro.
                  order: options.length - 1 - i,
                  count: options.length,
                  child: NexoFabMenuItem(
                    icon: options[i].icon,
                    label: options[i].label,
                    onPressed: () {
                      Navigator.of(context).pop();
                      options[i].onSelected();
                    },
                  ),
                ),
                SizedBox(height: spacing.sm),
              ],
              NexoFab(
                icon: LucideIcons.x,
                label: 'Fechar menu',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Sobe e aparece, uma opção depois da outra.
class _Entering extends StatelessWidget {
  const _Entering({
    required this.animation,
    required this.order,
    required this.count,
    required this.child,
  });

  final Animation<double> animation;
  final int order;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final step = 0.4 / count;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(order * step, order * step + 0.6, curve: motion.enter),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curved.value) * motion.distanceMedium),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// `Actions/FABMenu/Item` da lib: pílula de 56 em PrimaryContainer, ícone 20
/// e LabelMedium 600 em OnPrimaryContainer, padding 16/24, Elevation/3.
class NexoFabMenuItem extends StatelessWidget {
  const NexoFabMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final radius = BorderRadius.circular(context.shape.full);
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: context.elevation.level(3),
        ),
        child: NexoTappable(
          onTap: onPressed,
          borderRadius: radius,
          color: c.primaryContainer,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.xl, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: c.onPrimaryContainer),
                  SizedBox(width: spacing.sm),
                  Text(
                    label,
                    style: context
                        .textStyle(NexoTextStyles.labelMediumEmphasis)
                        .copyWith(color: c.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
