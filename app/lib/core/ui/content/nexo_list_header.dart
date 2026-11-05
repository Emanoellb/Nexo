import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';
import '../buttons/nexo_button.dart';

/// `Content/ListHeader` da lib: título (TitleMedium, anunciado como
/// cabeçalho), contagem opcional e ação Tertiary opcional ("Ver todas").
/// Altura mínima 48, recuo LG à esquerda, sem divisor próprio.
class NexoListHeader extends StatelessWidget {
  const NexoListHeader({
    super.key,
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
  });

  final String title;

  /// Ex.: "3 tarefas", "7 dias".
  final String? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: context.sizes.target),
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: spacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: spacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: textTheme.titleMedium!.copyWith(
                        color: c.onSurface,
                      ),
                    ),
                  ),
                  if (count != null)
                    Text(
                      count!,
                      style: textTheme.labelSmall!.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (actionLabel != null)
              NexoButton.tertiary(label: actionLabel!, onPressed: onAction),
          ],
        ),
      ),
    );
  }
}
