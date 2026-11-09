import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Altura do topo das abas (`NexoTabHeader`, com a barra de status), medida
/// pelo shell. O topo fica parado atrás das abas; as telas raiz começam logo
/// abaixo dele ([NexoTabRoot]) e os detalhes entram por cima, cobrindo-o.
/// Assim nada salta quando um detalhe abre ou fecha (o topo não some nem
/// aparece no meio da transição).
class NexoTabHeaderInset extends InheritedWidget {
  const NexoTabHeaderInset({
    super.key,
    required this.height,
    required super.child,
  });

  final double height;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NexoTabHeaderInset>()
          ?.height ??
      0;

  @override
  bool updateShouldNotify(NexoTabHeaderInset oldWidget) =>
      oldWidget.height != height;
}

/// Tela raiz de uma aba: começa abaixo do topo das abas (que já cuida da
/// barra de status).
class NexoTabRoot extends StatelessWidget {
  const NexoTabRoot({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: NexoTabHeaderInset.of(context)),
    child: MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: child,
    ),
  );
}

/// Avisa a altura do filho depois do layout (quando muda).
class SizeReporter extends SingleChildRenderObjectWidget {
  const SizeReporter({super.key, required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onHeight);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderSizeReporter).onHeight = onHeight;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _last) return;
    _last = height;
    SchedulerBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}

/// Deixa os toques da faixa de cima ([height]) atravessarem para o que está
/// atrás (o topo das abas), quando [enabled]. As rotas das abas têm uma
/// barreira invisível que, sem isso, engoliria o toque no sino e no avatar.
class TopPassThrough extends SingleChildRenderObjectWidget {
  const TopPassThrough({
    super.key,
    required this.height,
    required this.enabled,
    super.child,
  });

  final double height;
  final bool enabled;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTopPassThrough(height: height, enabled: enabled);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderTopPassThrough)
      ..height = height
      ..enabled = enabled;
  }
}

class _RenderTopPassThrough extends RenderProxyBox {
  _RenderTopPassThrough({required this.height, required this.enabled});

  double height;
  bool enabled;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (enabled && position.dy < height) return false;
    return super.hitTest(result, position: position);
  }
}
