import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_modal_route.dart';
import '../foundation/nexo_tappable.dart';

/// Um item de [showNexoMenu].
///
/// - Opção (`Menu/Item/Option`): [selected] não nulo; a atual ganha check,
///   peso 600 e fundo PrimaryContainer.
/// - Ação (`Menu/Item/Action`): ícone à esquerda; [destructive] em Error,
///   sempre por último, depois de um divisor.
@immutable
class NexoMenuItem {
  const NexoMenuItem({
    required this.label,
    this.icon,
    this.selected,
    this.destructive = false,
  });

  final String label;
  final IconData? icon;
  final bool? selected;
  final bool destructive;
}

/// `Menu/Select` e `Menu/Overflow` da lib: 256 de largura, padding XS,
/// SurfaceContainerLowest com borda Card/Border, `Shape/MD`, Elevation/2.
/// Abre preso a [anchor] (XS abaixo; acima se não couber), alinhado à
/// direita dele com [alignEnd]. A posição sai do tamanho real do menu
/// (cresce com a fonte ampliada); se não couber nem acima nem abaixo, fica
/// dentro da tela e rola. Fecha ao escolher, tocar fora ou voltar.
///
/// Com [growFrom] (toque longo, transições §8.4), o menu cresce desse ponto
/// (global) de `Scale/Enter` a 1, esmaecendo, em Short · Enter; a âncora do
/// toque longo é o próprio ponto ([anchorAt]).
///
/// Devolve o índice escolhido, ou `null`.
Future<int?> showNexoMenu(
  BuildContext context, {
  required Rect anchor,
  required List<NexoMenuItem> items,
  String label = 'Menu',
  bool alignEnd = true,
  Offset? growFrom,
}) {
  final c = context.nexoColors;
  final spacing = context.spacing;
  final motion = context.motion;
  final reduce = MediaQuery.disableAnimationsOf(context);

  // Entra esmaecendo em Short · Enter; sai em Instant · Exit.
  return showNexoModal<int>(
    context,
    barrierLabel: 'Fechar $label',
    barrierColor: c.scrim.withValues(alpha: 0),
    duration: reduce ? Duration.zero : motion.short,
    reverseDuration: reduce ? Duration.zero : motion.instant,
    transitionBuilder: (context, animation, _, child) {
      final faded = FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: motion.enter,
          reverseCurve: motion.exit.flipped,
        ),
        child: child,
      );
      final origin = growFrom;
      if (origin == null) return faded;
      // Cresce do ponto tocado só ao entrar (a página do menu ocupa a tela
      // inteira, então a origem global serve direto); sai só esmaecendo.
      return NexoEnterScale(
        animation: animation,
        from: motion.scaleEnter,
        curve: motion.enter,
        origin: origin,
        child: faded,
      );
    },
    pageBuilder: (menuContext, _, _) => CustomSingleChildLayout(
      delegate: _MenuLayout(
        anchor: anchor,
        alignEnd: alignEnd,
        gap: spacing.xs,
        margin: spacing.lg,
        safeArea: MediaQuery.paddingOf(menuContext),
      ),
      child: NexoMenu(
        label: label,
        items: items,
        onSelected: (i) => Navigator.of(menuContext).pop(i),
      ),
    ),
  );
}

/// Posiciona o menu pelo tamanho medido: abaixo do [anchor] se couber,
/// senão acima; sem espaço nos dois, encostado na margem (com rolagem).
class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout({
    required this.anchor,
    required this.alignEnd,
    required this.gap,
    required this.margin,
    required this.safeArea,
  });

  final Rect anchor;
  final bool alignEnd;
  final double gap;
  final double margin;
  final EdgeInsets safeArea;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          (constraints.maxWidth - margin * 2).clamp(0, NexoMenu.width),
          (constraints.maxHeight - safeArea.vertical - margin * 2).clamp(
            0,
            double.infinity,
          ),
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final maxX = size.width - margin - child.width;
    final x = (alignEnd ? anchor.right - child.width : anchor.left).clamp(
      margin,
      maxX < margin ? margin : maxX,
    );
    final top = safeArea.top + margin;
    final bottom = size.height - safeArea.bottom - margin;
    final below = anchor.bottom + gap;
    final above = anchor.top - gap - child.height;
    final double y;
    if (below + child.height <= bottom) {
      y = below;
    } else if (above >= top) {
      y = above;
    } else {
      y = (bottom - child.height).clamp(top, bottom);
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout old) =>
      anchor != old.anchor ||
      alignEnd != old.alignEnd ||
      gap != old.gap ||
      margin != old.margin ||
      safeArea != old.safeArea;
}

class NexoMenu extends StatelessWidget {
  const NexoMenu({
    super.key,
    required this.label,
    required this.items,
    required this.onSelected,
  });

  static const double width = 256;

  final String label;
  final List<NexoMenuItem> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final firstDestructive = items.indexWhere((i) => i.destructive);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: width,
          padding: EdgeInsets.all(spacing.xs),
          decoration: BoxDecoration(
            color: c.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(context.shape.md),
            border: Border.all(color: c.cardBorder),
            boxShadow: context.elevation.level(2),
          ),
          // Rola se a tela não comportar (fonte ampliada, paisagem).
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, item) in items.indexed) ...[
                  if (i == firstDestructive && i > 0)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: spacing.xs),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: c.outlineVariant,
                      ),
                    ),
                  _MenuRow(item: item, onTap: () => onSelected(i)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.onTap});

  final NexoMenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final selected = item.selected ?? false;
    final labelColor = item.destructive ? c.error : c.onSurface;
    final iconColor = item.destructive ? c.iconError : c.iconSecondary;
    final style = context
        .textStyle(
          selected
              ? NexoTextStyles.labelMediumEmphasis
              : NexoTextStyles.bodyMedium,
        )
        .copyWith(color: selected ? c.onPrimaryContainer : labelColor);
    return Semantics(
      button: true,
      selected: item.selected,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.shape.sm),
        // Lib: foco com anel interno (o item encosta no padding do menu).
        focusRingOutside: false,
        color: selected ? c.primaryContainer : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: context.sizes.target),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.md),
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, size: 20, color: iconColor),
                  SizedBox(width: spacing.md),
                ],
                Expanded(child: Text(item.label, style: style)),
                if (selected) ...[
                  SizedBox(width: spacing.md),
                  Icon(
                    LucideIcons.check,
                    size: 20,
                    color: c.onPrimaryContainer,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Âncora de menu no ponto tocado (toque longo): um retângulo vazio ali. O
/// menu nasce preso a ele e é empurrado para dentro da tela perto das
/// bordas.
Rect anchorAt(Offset point) => Rect.fromLTWH(point.dx, point.dy, 0, 0);
