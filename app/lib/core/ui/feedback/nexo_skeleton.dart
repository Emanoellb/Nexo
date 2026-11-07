import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/nexo_theme.dart';
import '../content/nexo_card.dart';

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
      _pulse
        ..duration = context.motion.pulse
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
          opacity: Tween<double>(
            begin: context.motion.pulseMinOpacity,
            end: 1,
          ).animate(_pulse),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Skeleton de um bloco de lista (Início e Tarefas): título e um cartão com
/// [rows] linhas de tarefa (caixinha + duas linhas de texto).
class NexoSkeletonList extends StatelessWidget {
  const NexoSkeletonList({super.key, required this.titleWidth, this.rows = 3});

  final double titleWidth;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NexoSkeleton(width: titleWidth, height: 16),
        SizedBox(height: spacing.md),
        NexoCard(
          radius: context.shape.lg,
          child: Column(
            children: [
              for (var i = 0; i < rows; i++) ...[
                if (i > 0) SizedBox(height: spacing.lg),
                Row(
                  children: [
                    NexoSkeleton(
                      width: 20,
                      height: 20,
                      radius: context.shape.xs,
                    ),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const NexoSkeleton(height: 12),
                          SizedBox(height: spacing.sm),
                          const NexoSkeleton(width: 140, height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Skeleton só se a carga passar de [skeletonDelay] (evita piscar em carga
/// rápida). No `build`: enquanto carrega, `return whileLoading(skeleton)`;
/// com os dados, chame [loaded].
mixin NexoDelayedSkeleton<T extends StatefulWidget> on State<T> {
  static const skeletonDelay = Duration(milliseconds: 300);

  Timer? _skeletonTimer;
  bool _skeletonDue = false;

  @override
  void initState() {
    super.initState();
    _skeletonTimer = Timer(skeletonDelay, () {
      if (mounted) setState(() => _skeletonDue = true);
    });
  }

  /// O [skeleton] depois do atraso; antes, nada.
  Widget whileLoading(Widget skeleton) =>
      _skeletonDue ? skeleton : const SizedBox.expand();

  /// Os dados chegaram: o skeleton não aparece mais.
  void loaded() => _skeletonTimer?.cancel();

  @override
  void dispose() {
    _skeletonTimer?.cancel();
    super.dispose();
  }
}
