import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/startup/app_startup.dart';
import '../../../core/data/local_flags.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/brand/nexo_animated_symbol.dart';
import '../application/splash_providers.dart';

/// Splash do Flutter, logo depois da splash nativa (mesmo símbolo, mesmo
/// tamanho e posição).
///
/// Roteiro aprovado em 26/10/2026, alongado em +2 s em 27/10/2026 (traço
/// mais lento + pausa com o símbolo pronto):
/// - traço reto 0–800 ms e traço curvo 550–1500 ms, `Motion/Easing/Emphasized`;
/// - símbolo pronto na tela até 2,7 s;
/// - só na 1ª abertura: "Bem-vindo ao Nexo" e "Do objetivo à ação do dia."
///   entram de 1100 a 1500 ms (`Enter`, subindo `distanceMedium`), com mais
///   ~600 ms para leitura (3,3 s no total);
/// - com "reduzir movimento": símbolo e texto estáticos, sem a pausa extra.
///
/// Sai quando a animação termina **e** a carga inicial ([appStartupProvider])
/// também, o que vier por último.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  /// Tamanho do símbolo: igual ao da splash nativa (128 dp).
  static const double symbolSize = 128;

  // Linha do tempo, em ms.
  static const _straightEnd = 800;
  static const _curveStart = 550;
  static const _textStart = 1100;
  static const _drawEnd = 1500;

  /// Desenho do símbolo (e entrada do texto, que termina junto).
  static const drawDuration = Duration(milliseconds: _drawEnd);

  /// Símbolo pronto na tela antes de seguir.
  static const holdPause = Duration(milliseconds: 1200);

  /// Leitura das boas-vindas, só na 1ª abertura.
  static const readingPause = Duration(milliseconds: 600);

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
        : SplashPage.drawDuration +
              SplashPage.holdPause +
              (_firstOpen ? SplashPage.readingPause : Duration.zero);
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
    try {
      await ref.read(appStartupProvider.future);
    } catch (error, stack) {
      // A splash não pode prender o usuário: registra e segue.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'nexo startup',
        ),
      );
    }
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
              : _phase(0, SplashPage._straightEnd, motion.emphasized);
          final curve = reduceMotion
              ? 1.0
              : _phase(
                  SplashPage._curveStart,
                  SplashPage._drawEnd,
                  motion.emphasized,
                );
          final text = reduceMotion
              ? 1.0
              : _phase(
                  SplashPage._textStart,
                  SplashPage._drawEnd,
                  motion.enter,
                );

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
