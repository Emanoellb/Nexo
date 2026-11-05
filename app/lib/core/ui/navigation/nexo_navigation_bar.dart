import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';

/// Um destino da [NexoNavigationBar].
@immutable
class NexoNavigationDestination {
  const NexoNavigationDestination({required this.icon, required this.label});

  final IconData icon;

  /// Sempre visível, embaixo do ícone.
  final String label;
}

/// `Navigation/BottomBar` da lib (aprovada em 04/11/2026): a cápsula de vidro
/// com os destinos ([NexoNavigationBar]) e, à direita, o botão "+"
/// ([NexoFab]), com margens laterais e acima da área segura.
class NexoBottomBar extends StatelessWidget {
  const NexoBottomBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onCreate,
    this.solid = false,
    this.fabKey,
  });

  final List<NexoNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Botão "+" (Criar): abre o menu do "+".
  final VoidCallback? onCreate;

  /// Para o menu do "+" saber onde o botão está.
  final Key? fabKey;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: NexoNavigationBar(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
              solid: solid,
            ),
          ),
          SizedBox(width: spacing.sm),
          NexoFab(key: fabKey, onPressed: onCreate),
        ],
      ),
    );
  }
}

/// `Navigation/NavigationBar/Floating` da lib: cápsula "Nexo Glass" com
/// destinos de mesma largura, ícone em cima e nome sempre visível embaixo.
/// [solid] troca o vidro por superfície sólida (contraste alto ou "reduzir
/// transparência").
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

    final items = Padding(
      padding: EdgeInsets.all(spacing.xs),
      child: Row(
        children: [
          for (var i = 0; i < destinations.length; i++)
            Expanded(
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
      ),
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
        child: items,
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
              child: items,
            ),
          ),
        ),
      );
    }

    return Semantics(container: true, explicitChildNodes: true, child: surface);
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

  /// Altura do alvo (o item inteiro).
  static const double height = 56;

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
    final radius = BorderRadius.circular(context.shape.full);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : motion.short;

    final Color icon = selected
        ? c.glassContentSelected
        : (solid ? c.iconSecondary : c.glassContent);
    final Color label = selected
        ? c.glassContentSelected
        : (solid ? c.onSurfaceVariant : c.glassContent);
    final Color? indicator = selected
        ? (solid ? c.selected : c.glassIndicator)
        : null;
    final TextStyle style =
        (selected
                ? NexoTextStyles.labelSmallEmphasis
                : NexoTextStyles.labelSmall)
            .copyWith(color: label);

    return Semantics(
      button: true,
      selected: selected,
      label: '${destination.label}, aba $position de $count',
      onTap: onTap,
      excludeSemantics: true,
      // Pílula atrás do item inteiro (ícone + nome), trocada em 150 ms.
      child: AnimatedContainer(
        duration: duration,
        curve: motion.standard,
        decoration: BoxDecoration(color: indicator, borderRadius: radius),
        child: NexoTappable(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: height),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.xs),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(destination.icon, size: 24, color: icon),
                  SizedBox(height: spacing.xs),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: style,
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

/// `Actions/FAB` da lib: botão circular de 64 px em Primary, com o ícone
/// "+", Elevation/3 e nome acessível "Criar".
class NexoFab extends StatelessWidget {
  const NexoFab({
    super.key,
    required this.onPressed,
    this.icon = LucideIcons.plus,
    this.label = 'Criar',
  });

  static const double size = 64;

  final VoidCallback? onPressed;
  final IconData icon;

  /// Nome lido pelo leitor de tela.
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final radius = BorderRadius.circular(context.shape.full);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: context.elevation.level(3),
          ),
          child: NexoTappable(
            onTap: onPressed,
            borderRadius: radius,
            color: enabled ? c.primary : c.disabledBackground,
            child: SizedBox.square(
              dimension: size,
              child: Icon(
                icon,
                size: 24,
                color: enabled ? c.onPrimary : c.iconDisabled,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
