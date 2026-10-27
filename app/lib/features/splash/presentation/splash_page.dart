import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/local_flags.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/brand/nexo_animated_symbol.dart';
import '../application/splash_providers.dart';

/// Splash do Flutter, logo depois da splash nativa (mesmo símbolo, mesmo
/// tamanho e posição).
///
/// Roteiro aprovado em 26/10/2026:
/// - traço reto 0–380 ms e traço curvo 250–700 ms, `Motion/Easing/Emphasized`;
/// - só na 1ª abertura: "Bem-vindo ao Nexo" e "Do objetivo à ação do dia."
///   entram de 500 a 750 ms (`Enter`, subindo `distanceMedium`), com ~600 ms
///   para leitura;
/// - com "reduzir movimento": símbolo e texto estáticos.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  /// Tamanho do símbolo: igual ao da splash nativa (128 dp).
  static const double symbolSize = 128;

  static const drawDuration = Duration(milliseconds: 700);
  static const readingPause = Duration(milliseconds: 600);
  static const textIn = Duration(milliseconds: 750);

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final bool _firstOpen = !ref.read(localFlagsProvider).firstOpenDone;
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // Sem movimento, só sobra a pausa de leitura (na 1ª abertura).
    final total = reduceMotion
        ? (_firstOpen ? SplashPage.readingPause : Duration.zero)
        : (_firstOpen
              ? SplashPage.textIn + SplashPage.readingPause
              : SplashPage.drawDuration);
    if (total == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    } else {
      _controller
        ..duration = total
        ..forward();
    }
  }

  Future<void> _finish() async {
    if (!mounted) return;
    if (_firstOpen) await ref.read(localFlagsProvider).markFirstOpenDone();
    if (mounted) ref.read(splashFinishedProvider.notifier).finish();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fração da linha do tempo entre [start] e [end] (em ms), com [curve].
  double _phase(int start, int end, Curve curve) {
    final totalMs = _controller.duration?.inMilliseconds ?? 0;
    if (totalMs == 0) return 1;
    final nowMs = _controller.value * totalMs;
    final t = ((nowMs - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final motion = context.motion;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: c.surface,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final straight = reduceMotion
              ? 1.0
              : _phase(0, 380, motion.emphasized);
          final curve = reduceMotion
              ? 1.0
              : _phase(250, 700, motion.emphasized);
          final text = reduceMotion ? 1.0 : _phase(500, 750, motion.enter);

          return LayoutBuilder(
            builder: (context, constraints) {
              final center = constraints.maxHeight / 2;
              return Stack(
                children: [
                  Center(
                    child: Hero(
                      tag: nexoLogoHeroTag,
                      child: Semantics(
                        label: 'Nexo',
                        image: true,
                        child: NexoAnimatedSymbol(
                          size: SplashPage.symbolSize,
                          straight: straight,
                          curve: curve,
                        ),
                      ),
                    ),
                  ),
                  if (_firstOpen)
                    Positioned(
                      top: center + SplashPage.symbolSize / 2 + spacing.xl,
                      left: spacing.xl,
                      right: spacing.xl,
                      child: Opacity(
                        opacity: text,
                        child: Transform.translate(
                          offset: Offset(0, (1 - text) * motion.distanceMedium),
                          child: Column(
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  'Bem-vindo ao Nexo',
                                  textAlign: TextAlign.center,
                                  style: textTheme.titleLarge!.copyWith(
                                    color: c.onSurface,
                                  ),
                                ),
                              ),
                              SizedBox(height: spacing.xs),
                              Text(
                                'Do objetivo à ação do dia.',
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium!.copyWith(
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
