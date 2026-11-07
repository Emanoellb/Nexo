import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';
import 'nexo_card.dart';

/// `Content/List` em cartão (Card/Default, Shape/LG, borda) com divisores
/// (OutlineVariant, recuo LG), como os blocos do Início e as seções de
/// Tarefas.
class NexoCardList extends StatelessWidget {
  const NexoCardList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    return NexoCard(
      padding: EdgeInsets.zero,
      radius: context.shape.lg,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: c.outlineVariant,
                ),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}
