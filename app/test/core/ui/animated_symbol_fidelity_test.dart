import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/theme/nexo_theme.dart';
import 'package:nexo/core/ui/ui.dart';
import 'package:nexo/core/ui/brand/nexo_animated_symbol.dart';

/// O símbolo desenhado a partir dos traços convertidos precisa ser a logo
/// oficial: compara, pixel a pixel, o fim da animação com o SVG do pacote.
void main() {
  testWidgets('símbolo animado completo = SVG oficial', (tester) async {
    const size = 160.0;
    final animatedKey = GlobalKey();
    final svgKey = GlobalKey();

    tester.view.physicalSize = const Size(400, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: NexoTheme.light(),
        home: Row(
          children: [
            RepaintBoundary(
              key: animatedKey,
              child: const NexoAnimatedSymbol(
                size: size,
                straight: 1,
                curve: 1,
              ),
            ),
            RepaintBoundary(
              key: svgKey,
              child: const NexoLogoSymbol(size: size),
            ),
          ],
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    Future<List<int>> alphaOf(GlobalKey key) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return data!.buffer.asUint8List();
      });
      return [for (var i = 3; i < bytes!.length; i += 4) bytes[i]];
    }

    final animated = await alphaOf(animatedKey);
    final svg = await alphaOf(svgKey);
    expect(animated.length, svg.length);

    var inked = 0;
    var differing = 0;
    for (var i = 0; i < svg.length; i++) {
      final a = animated[i] > 127;
      final b = svg[i] > 127;
      if (a || b) inked++;
      if (a != b) differing++;
    }
    // Só a borda serrilhada pode variar entre os dois renderizadores.
    expect(inked, greaterThan(1000));
    expect(differing / inked, lessThan(0.02));
  });
}
