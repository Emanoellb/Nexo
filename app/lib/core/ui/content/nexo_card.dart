import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';
import '../foundation/nexo_tappable.dart';

/// `Content/Card` da lib: Card/Default, borda Card/Border de 1 px, Shape/MD
/// e padding LG. No escuro, a borda e o tom separam o cartão do fundo.
///
/// - [padding] `null` usa LG; listas com divisores passam `EdgeInsets.zero`.
/// - [radius] `null` usa MD; as listas do Início usam LG (design).
/// - [clip] recorta o conteúdo no raio (para a tinta do toque nas linhas).
/// - [onTap] torna o cartão inteiro tocável (ex.: o plano do Início abre o
///   detalhe); os botões de dentro continuam com o próprio toque.
class NexoCard extends StatelessWidget {
  const NexoCard({
    super.key,
    required this.child,
    this.padding,
    this.radius,
    this.clip = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final bool clip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final borderRadius = BorderRadius.circular(radius ?? context.shape.md);
    Widget content = Padding(
      padding: padding ?? EdgeInsets.all(context.spacing.lg),
      child: child,
    );
    if (onTap != null) {
      return NexoTappable(
        onTap: onTap,
        borderRadius: borderRadius,
        color: c.cardDefault,
        side: BorderSide(color: c.cardBorder),
        child: content,
      );
    }
    if (clip) {
      content = ClipRRect(borderRadius: borderRadius, child: content);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.cardDefault,
        borderRadius: borderRadius,
        border: Border.all(color: c.cardBorder),
      ),
      child: content,
    );
  }
}
