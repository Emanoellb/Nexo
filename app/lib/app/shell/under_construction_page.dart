import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/nexo_theme.dart';

/// Marcador provisório de uma tela que ainda será prototipada. Some quando a
/// tela real do bloco indicado entrar.
class UnderConstructionPage extends StatelessWidget {
  const UnderConstructionPage({
    super.key,
    required this.title,
    required this.block,
  });

  final String title;

  /// Bloco do plano em que a tela entra (ex.: "bloco 3 · Planos").
  final String block;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(context.spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.construction,
                  size: 24,
                  color: c.iconSecondary,
                ),
                SizedBox(height: context.spacing.md),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: textTheme.titleLarge!.copyWith(color: c.onSurface),
                  ),
                ),
                SizedBox(height: context.spacing.xs),
                Text(
                  'Em construção · $block',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium!.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
