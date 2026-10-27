import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_parsing/path_parsing.dart';

import 'nexo_symbol_paths.dart';

/// Tag do Hero da logo: a splash e a tela de Login usam a mesma, para o
/// símbolo "voar" até a posição da logo do Login.
const nexoLogoHeroTag = 'nexo-logo';

/// Símbolo do Nexo sendo revelado traço a traço, a partir dos traços do SVG
/// oficial (nada é redesenhado).
///
/// - [straight]: 0 → 1 revela o traço reto, de cima à esquerda até embaixo à
///   direita (passando por baixo do curvo).
/// - [curve]: 0 → 1 revela o traço curvo, de baixo à esquerda até em cima à
///   direita.
///
/// Decorativo: quem usa dá o nome acessível.
class NexoAnimatedSymbol extends StatelessWidget {
  const NexoAnimatedSymbol({
    super.key,
    required this.size,
    required this.straight,
    required this.curve,
  });

  final double size;
  final double straight;
  final double curve;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SymbolPainter(
        color: Theme.of(context).colorScheme.primary,
        straight: straight.clamp(0, 1),
        curve: curve.clamp(0, 1),
      ),
    );
  }
}

class _PathBuilder implements PathProxy {
  final Path path = Path();

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}

Path _partPath(NexoSymbolPart part) {
  final builder = _PathBuilder();
  writeSvgPathDataToPath(part.d, builder);
  // translate(tx ty) scale(s): matriz 4x4 em ordem de coluna.
  final s = part.scale;
  final matrix = Float64List.fromList([
    s, 0, 0, 0, //
    0, s, 0, 0, //
    0, 0, 1, 0, //
    part.tx, part.ty, 0, 1, //
  ]);
  return builder.path.transform(matrix);
}

/// Traços já convertidos, na caixa de 160 × 160.
final Path _straightPath = Path()
  ..addPath(_partPath(nexoSymbolParts[0]), Offset.zero)
  ..addPath(_partPath(nexoSymbolParts[1]), Offset.zero);
final Path _curvePath = _partPath(nexoSymbolParts[2]);

class _SymbolPainter extends CustomPainter {
  _SymbolPainter({
    required this.color,
    required this.straight,
    required this.curve,
  });

  final Color color;
  final double straight;
  final double curve;

  /// Borda suave da revelação, em fração do eixo.
  static const _feather = 0.06;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / nexoSymbolBox, size.height / nexoSymbolBox);
    _reveal(
      canvas,
      _straightPath,
      straight,
      const Offset(0, 0),
      const Offset(nexoSymbolBox, nexoSymbolBox),
    );
    _reveal(
      canvas,
      _curvePath,
      curve,
      const Offset(0, nexoSymbolBox),
      const Offset(nexoSymbolBox, 0),
    );
    canvas.restore();
  }

  void _reveal(Canvas canvas, Path path, double t, Offset from, Offset to) {
    if (t <= 0) return;
    final paint = Paint()..isAntiAlias = true;
    if (t >= 1) {
      paint.color = color;
    } else {
      final clear = color.withValues(alpha: 0);
      final edge = t * (1 + _feather);
      paint.shader = ui.Gradient.linear(
        from,
        to,
        [color, color, clear, clear],
        [0, (edge - _feather).clamp(0, 1), edge.clamp(0, 1), 1],
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SymbolPainter old) =>
      old.straight != straight || old.curve != curve || old.color != color;
}
