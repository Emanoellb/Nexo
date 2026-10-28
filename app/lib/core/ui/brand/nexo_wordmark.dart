import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'nexo_logo.dart';

/// Nome integrado da marca ("ne×o"): o símbolo é o "x" do nome.
///
/// Arte oficial em SVG (assets/brand/logo/svg), recortada no conteúdo: a
/// área de proteção (≥ 25% da largura do símbolo) fica com quem posiciona.
/// Versão clara ou escura pelo brilho do tema. Com [heroTag], o "x" recebe o
/// símbolo que voa da splash.
class NexoWordmark extends StatelessWidget {
  const NexoWordmark({super.key, this.height = 32, this.heroTag});

  static const _light = 'assets/brand/logo/svg/nexo-nome-integrado-claro.svg';
  static const _dark = 'assets/brand/logo/svg/nexo-nome-integrado-escuro.svg';

  /// viewBox dos arquivos.
  static const _viewBox = Size(162.65, 45.891);

  /// Quadrado do símbolo (viewBox 160, com respiro de 4%) sobre o "x", em
  /// unidades do viewBox (medidas da sessão da marca, 27/10/2026).
  static const _symbol = Rect.fromLTWH(80.416, -1.790, 40.217, 40.217);

  /// Altura do nome, sem a área de proteção.
  final double height;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final scale = height / _viewBox.height;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tag = heroTag;
    return SizedBox(
      width: _viewBox.width * scale,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              dark ? _dark : _light,
              semanticsLabel: 'Nexo',
            ),
          ),
          if (tag != null)
            Positioned(
              left: _symbol.left * scale,
              top: _symbol.top * scale,
              width: _symbol.width * scale,
              height: _symbol.height * scale,
              // O destino é vazio: em voo aparece o símbolo, e ao pousar
              // fica o "x" da própria arte.
              child: Hero(
                tag: tag,
                flightShuttleBuilder: (_, _, _, _, _) => const FittedBox(
                  child: NexoLogoSymbol(size: 128, semanticLabel: null),
                ),
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }
}
