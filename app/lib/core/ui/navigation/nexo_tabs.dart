import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';

/// `Navigation/Tabs` + `Navigation/TabItem` da lib: abas de largura igual
/// (2–4), 48 de altura, borda inferior OutlineVariant. Selecionada: Primary
/// + peso 600 + indicador de 3 px só sob o rótulo e a contagem (como as abas
/// principais do M3). Contagem opcional ao lado do rótulo. Papéis "tab bar"
/// e "tab" para o leitor de tela.
class NexoTabs extends StatelessWidget {
  const NexoTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  /// Indicador da aba selecionada (lib: 3 px).
  static const double indicator = 3;

  final List<({String label, int? count})> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    return Semantics(
      role: SemanticsRole.tabBar,
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.outlineVariant)),
        ),
        child: Row(
          children: [
            for (final (i, tab) in tabs.indexed)
              Expanded(
                child: _Tab(
                  label: tab.label,
                  count: tab.count,
                  selected: i == selected,
                  position: i + 1,
                  total: tabs.length,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.count,
    required this.selected,
    required this.position,
    required this.total,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool selected;
  final int position;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final color = selected ? c.primary : c.onSurfaceVariant;
    final text = context
        .textStyle(
          selected
              ? NexoTextStyles.labelMediumEmphasis
              : NexoTextStyles.labelMedium,
        )
        .copyWith(color: color);
    final spoken = count == null ? label : '$label, $count';
    return Semantics(
      role: SemanticsRole.tab,
      selected: selected,
      label: '$spoken, aba $position de $total',
      onTap: onTap,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: context.sizes.target),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // O indicador fica só sob o conteúdo (lib: "Conteúdo").
                  Flexible(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: selected
                                ? c.primary
                                : c.primary.withValues(alpha: 0),
                            width: NexoTabs.indicator,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text,
                            ),
                          ),
                          if (count != null) ...[
                            SizedBox(width: spacing.xs),
                            Text(
                              '$count',
                              style: context
                                  .textStyle(NexoTextStyles.labelSmall)
                                  .copyWith(color: color),
                            ),
                          ],
                        ],
                      ),
                    ),
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
