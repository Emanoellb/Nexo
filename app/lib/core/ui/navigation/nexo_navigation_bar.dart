import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';

/// Um destino da [NexoNavigationBar].
@immutable
class NexoNavigationDestination {
  const NexoNavigationDestination({required this.icon, required this.label});

  final IconData icon;

  /// Visível só no destino selecionado; sempre lido pelo leitor de tela.
  final String label;
}

/// Barra de navegação flutuante "Nexo Glass" (decisão de 26/10/2026):
/// - todos os destinos são iguais, sem botão central elevado;
/// - o nome aparece só no destino selecionado, mas todos têm nome acessível;
/// - [solid] troca o vidro por superfície sólida (contraste alto ou "reduzir
///   transparência").
///
/// Detalhes finos (medidas, ícones) a conferir com o `nexo.lib.pen` em 28/10.
class NexoNavigationBar extends StatelessWidget {
  const NexoNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.solid = false,
  });

  final List<NexoNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final radius = BorderRadius.circular(context.shape.full);

    // O destino selecionado pode encolher: com fonte ampliada, o nome é
    // cortado com reticências em vez de estourar a barra. Os outros mantêm
    // o alvo de 48 px.
    final items = Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (var i = 0; i < destinations.length; i++)
          Flexible(
            flex: i == selectedIndex ? 1 : 0,
            child: _NavItem(
              destination: destinations[i],
              selected: i == selectedIndex,
              solid: solid,
              position: i + 1,
              count: destinations.length,
              onTap: () => onSelected(i),
            ),
          ),
      ],
    );

    final Widget surface;
    if (solid) {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          color: c.glassFallback,
          borderRadius: radius,
          border: Border.all(color: c.outlineVariant),
          boxShadow: context.elevation.level(2),
        ),
        child: Padding(padding: EdgeInsets.all(spacing.xs), child: items),
      );
    } else {
      final blur = context.glass.blur;
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: context.elevation.level(2),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.glassFill,
                borderRadius: radius,
                border: Border.all(color: c.glassEdge),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.glassSheen, c.glassSheenEnd],
                ),
              ),
              child: Padding(padding: EdgeInsets.all(spacing.xs), child: items),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.sm),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: surface,
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.solid,
    required this.position,
    required this.count,
    required this.onTap,
  });

  final NexoNavigationDestination destination;
  final bool selected;
  final bool solid;
  final int position;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final motion = context.motion;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : motion.short;

    final Color content = selected
        ? c.glassContentSelected
        : (solid ? c.iconSecondary : c.glassContent);
    final Color? indicator = selected
        ? (solid ? c.selected : c.glassIndicator)
        : null;

    return Semantics(
      button: true,
      selected: selected,
      label: '${destination.label}, aba $position de $count',
      onTap: onTap,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.shape.full),
        color: indicator,
        child: AnimatedSize(
          duration: duration,
          curve: motion.standard,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: selected ? spacing.lg : spacing.md,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(destination.icon, size: 24, color: content),
                  if (selected) ...[
                    SizedBox(width: spacing.sm),
                    Flexible(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge!
                            .copyWith(color: content),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
