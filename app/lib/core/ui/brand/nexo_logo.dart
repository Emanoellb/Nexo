import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Símbolo da marca Nexo (o "x como ponto de encontro").
///
/// Regras de uso em assets/brand/README.md: tamanho mínimo de 16 px e área
/// de proteção de 25% da largura em volta, que fica com quem posiciona.
/// A cor vem do tema (`colorScheme.primary` = `Brand/Mark` no tema claro), por
/// isso o mesmo arquivo serve para o dark mode futuro.
class NexoLogoSymbol extends StatelessWidget {
  const NexoLogoSymbol({super.key, this.size = 32, this.semanticLabel = 'Nexo'})
    : assert(size >= minSize, 'O símbolo não pode ficar menor que 16 px.');

  static const double minSize = 16;
  static const String _asset = 'assets/brand/logo/svg/nexo-simbolo-claro.svg';

  final double size;

  /// Nome lido pelo leitor de tela. Passe `null` quando o símbolo for só
  /// decorativo, ao lado de um texto que já diga "Nexo".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final symbol = SvgPicture.asset(
      _asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        Theme.of(context).colorScheme.primary,
        BlendMode.srcIn,
      ),
      excludeFromSemantics: true,
    );
    if (semanticLabel == null) return ExcludeSemantics(child: symbol);
    return Semantics(label: semanticLabel, image: true, child: symbol);
  }
}
