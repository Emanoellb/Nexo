import 'package:flutter/material.dart';

import '../../core/theme/nexo_theme.dart';

/// Troca de aba em *fade through* (M3; transições aprovadas em 08/11/2026):
/// a aba que sai esmaece de 1 a 0 nos primeiros 35%; a que entra esmaece de
/// 0 a 1 e cresce de `Motion/Scale/Enter` a 1 nos 65% finais. Medium ·
/// Standard. Sem deslocamento: as abas não têm ordem espacial.
///
/// Todas as abas ficam montadas (estado e rolagem mantidos, como o
/// `IndexedStack`); as que não aparecem ficam fora do palco, sem animações
/// e fora do leitor de tela. Com "reduzir movimento", troca seca.
class FadeThroughBranches extends StatefulWidget {
  const FadeThroughBranches({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<FadeThroughBranches> createState() => _FadeThroughBranchesState();
}

class _FadeThroughBranchesState extends State<FadeThroughBranches>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, value: 1);
  int? _previous;

  @override
  void didUpdateWidget(FadeThroughBranches old) {
    super.didUpdateWidget(old);
    if (old.currentIndex == widget.currentIndex) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _previous = null;
      _controller.value = 1;
      return;
    }
    _previous = old.currentIndex;
    _controller
      ..duration = context.motion.medium
      ..forward(from: 0).whenCompleteOrCancel(() {
        if (mounted) setState(() => _previous = null);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final out = CurvedAnimation(
      parent: _controller,
      curve: Interval(0, 0.35, curve: motion.standard),
    );
    final into = CurvedAnimation(
      parent: _controller,
      curve: Interval(0.35, 1, curve: motion.standard),
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            _branch(i, out.value, into.value, motion.scaleEnter),
        ],
      ),
    );
  }

  /// A mesma estrutura para todas as abas, sempre: mudar o pai de uma aba
  /// recriaria o estado dela.
  Widget _branch(int i, double out, double into, double scaleEnter) {
    final current = i == widget.currentIndex;
    final leaving = i == _previous && _controller.isAnimating;
    final visible = current || leaving;
    final double opacity;
    final double scale;
    if (current && _previous != null && _controller.isAnimating) {
      opacity = into;
      scale = scaleEnter + (1 - scaleEnter) * into;
    } else if (leaving) {
      opacity = 1 - out;
      scale = 1;
    } else {
      opacity = 1;
      scale = 1;
    }
    return Offstage(
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: ExcludeSemantics(
          // A que sai não conta para o leitor de tela.
          excluding: !current,
          child: IgnorePointer(
            ignoring: !current,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(scale: scale, child: widget.children[i]),
            ),
          ),
        ),
      ),
    );
  }
}
