import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';

/// `Feedback/Skeleton` da lib: bloco em SurfaceContainer com a forma do
/// conteúdo final. Pulsa de leve; parado com "reduzir movimento". Oculto do
/// leitor de tela: quem monta a tela anuncia o carregamento no container
/// ([NexoSkeletonScope]).
class NexoSkeleton extends StatelessWidget {
  const NexoSkeleton({
    super.key,
    this.width,
    required this.height,
    this.radius,
  });

  /// `null` ocupa a largura disponível.
  final double? width;
  final double height;

  /// Padrão: `Shape/Full` (como na lib); blocos grandes usam `Shape/MD`.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.nexoColors.surfaceContainer,
          borderRadius: BorderRadius.circular(radius ?? context.shape.full),
        ),
      ),
    );
  }
}

/// Container de carregamento: anuncia [label] ao leitor de tela, esconde os
/// blocos e aplica o pulso discreto (sem pulso com "reduzir movimento").
class NexoSkeletonScope extends StatefulWidget {
  const NexoSkeletonScope({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  State<NexoSkeletonScope> createState() => _NexoSkeletonScopeState();
}

class _NexoSkeletonScopeState extends State<NexoSkeletonScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = 1;
    } else if (!_pulse.isAnimating) {
      // Sem token para laço: um ciclo lento, de 3 × Motion/Duration/Long.
      _pulse
        ..duration = context.motion.long * 3
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.55, end: 1).animate(_pulse),
          child: widget.child,
        ),
      ),
    );
  }
}
