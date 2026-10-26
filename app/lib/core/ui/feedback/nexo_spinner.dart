import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Indicador de carregamento da lib: ícone Lucide `loader-circle` girando.
///
/// Decorativo para o leitor de tela: quem usa anuncia o "carregando".
/// Com "reduzir movimento" ligado no sistema, fica parado.
class NexoSpinner extends StatefulWidget {
  const NexoSpinner({super.key, required this.color, this.size = 20});

  final Color color;
  final double size;

  @override
  State<NexoSpinner> createState() => _NexoSpinnerState();
}

class _NexoSpinnerState extends State<NexoSpinner>
    with SingleTickerProviderStateMixin {
  // Rotação contínua: não há token de duração para loop, 1 volta por segundo.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RotationTransition(
        turns: _controller,
        child: Icon(
          LucideIcons.loaderCircle,
          size: widget.size,
          color: widget.color,
        ),
      ),
    );
  }
}
