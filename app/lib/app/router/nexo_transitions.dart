import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/nexo_theme.dart';

/// Tipo de transição de uma tela (padrão de transições aprovado em
/// 08/11/2026, `pen.dev/notas/transicoes-especificacao.md` §3).
enum NexoPageMotion {
  /// Sem entrada (raiz de aba, aberta pelo fade through do shell).
  none,

  /// Esmaecimento: troca de contexto (Splash → Início, Login → Início).
  fade,

  /// Esmaecimento longo: Splash → Login (com o Hero da logo) e Tutorial.
  fadeLong,

  /// Eixo compartilhado X: avançar para dentro (detalhes, Perfil, legais e
  /// Auth). Quem entra vem da direita (`distancePage`, 30); quem está
  /// embaixo vai para a esquerda.
  sharedAxisX,

  /// Subir com esmaecimento: criar ou editar por cima das abas.
  slideUp,

  /// Entrar no Foco: sobe com esmaecimento, em ênfase (Long · Emphasized).
  /// Minimizar (pedido do usuário, 09/11/2026): a tela inteira encolhe
  /// descendo até a Barra do foco ([NexoTransitionPage.morphTarget]), em
  /// Long · Emphasized; sem a barra (encerrou), desce como o inverso.
  focus,
}

/// Página do roteador com o padrão do Nexo. Abrir em Medium (Long no
/// [NexoPageMotion.fadeLong]); fechar e voltar em Short, sempre o inverso.
/// Com "reduzir movimento", duração zero (corte seco).
class NexoTransitionPage<T> extends Page<T> {
  const NexoTransitionPage({
    required this.child,
    required this.motion,
    required this.tokens,
    required this.reduceMotion,
    this.morphTarget,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  /// Página do [state] do go_router, com os tokens de [context].
  factory NexoTransitionPage.of(
    BuildContext context,
    GoRouterState state,
    Widget child,
    NexoPageMotion motion, {
    GlobalKey? morphTarget,
  }) => NexoTransitionPage(
    key: state.pageKey,
    name: state.name ?? state.path,
    arguments: state.extra,
    restorationId: state.pageKey.value,
    child: child,
    motion: motion,
    tokens: context.motion,
    reduceMotion: MediaQuery.disableAnimationsOf(context),
    morphTarget: morphTarget,
  );

  final Widget child;
  final NexoPageMotion motion;
  final NexoMotion tokens;
  final bool reduceMotion;

  /// Só no [NexoPageMotion.focus]: o widget em que a tela encolhe ao sair.
  final GlobalKey? morphTarget;

  @override
  Route<T> createRoute(BuildContext context) => NexoPageRoute<T>(page: this);
}

/// Rota de uma [NexoTransitionPage]. O que está embaixo só se move quando
/// a tela nova é de eixo X (a de subir cobre por cima, sem empurrar).
class NexoPageRoute<T> extends PageRoute<T> {
  NexoPageRoute({required NexoTransitionPage<T> page}) : super(settings: page);

  NexoTransitionPage<T> get _page => settings as NexoTransitionPage<T>;

  NexoPageMotion get motion => _page.motion;

  @override
  Duration get transitionDuration {
    final page = _page;
    if (page.reduceMotion || page.motion == NexoPageMotion.none) {
      return Duration.zero;
    }
    return page.motion == NexoPageMotion.fadeLong ||
            page.motion == NexoPageMotion.focus
        ? page.tokens.long
        : page.tokens.medium;
  }

  @override
  Duration get reverseTransitionDuration {
    final page = _page;
    if (page.reduceMotion || page.motion == NexoPageMotion.none) {
      return Duration.zero;
    }
    return page.motion == NexoPageMotion.fadeLong ||
            page.motion == NexoPageMotion.focus
        ? page.tokens.long
        : page.tokens.short;
  }

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is NexoPageRoute &&
      nextRoute.motion == NexoPageMotion.sharedAxisX;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: _page.child,
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final t = _page.tokens;
    final entering = switch (motion) {
      NexoPageMotion.none => child,
      NexoPageMotion.fade || NexoPageMotion.fadeLong => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: t.standard),
        child: child,
      ),
      NexoPageMotion.sharedAxisX => _Slide(
        animation: animation,
        axis: Axis.horizontal,
        distance: t.distancePage,
        move: t.emphasized,
        // A opacidade entra depois do começo do deslize (M3).
        fade: Interval(0.3, 1, curve: t.standard),
        // Voltar: Short · Exit (§7.1).
        reverseMove: t.exit,
        child: child,
      ),
      NexoPageMotion.slideUp => _Slide(
        animation: animation,
        axis: Axis.vertical,
        distance: t.distanceLarge,
        move: t.emphasized,
        fade: t.standard,
        reverseMove: t.exit,
        child: child,
      ),
      NexoPageMotion.focus => _FocusMinimize(
        animation: animation,
        target: _page.morphTarget,
        child: _Slide(
          animation: animation,
          axis: Axis.vertical,
          distance: t.distanceLarge,
          move: t.emphasized,
          fade: t.standard,
          reverseMove: t.exit,
          child: child,
        ),
      ),
    };
    // Embaixo de uma tela de eixo X: vai para a esquerda e esmaece no
    // começo (o contrário ao voltar).
    return _SlideOut(
      animation: secondaryAnimation,
      distance: t.distancePage,
      move: t.emphasized,
      fade: Interval(0, 0.3, curve: t.standard),
      child: entering,
    );
  }
}

/// Entra deslizando [distance] (direita ou de baixo) até 0 e esmaecendo.
class _Slide extends StatelessWidget {
  const _Slide({
    required this.animation,
    required this.axis,
    required this.distance,
    required this.move,
    required this.fade,
    required this.reverseMove,
    required this.child,
  });

  final Animation<double> animation;
  final Axis axis;
  final double distance;
  final Curve move;
  final Curve fade;
  final Curve reverseMove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final moving = CurvedAnimation(
      parent: animation,
      curve: move,
      reverseCurve: reverseMove.flipped,
    );
    final opacity = CurvedAnimation(parent: animation, curve: fade);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final d = (1 - moving.value) * distance;
        return Opacity(
          opacity: opacity.value,
          child: Transform.translate(
            offset: axis == Axis.horizontal
                ? Offset(rtl ? -d : d, 0)
                : Offset(0, d),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Sai para a esquerda [distance] e esmaece (tela de baixo no eixo X).
class _SlideOut extends StatelessWidget {
  const _SlideOut({
    required this.animation,
    required this.distance,
    required this.move,
    required this.fade,
    required this.child,
  });

  final Animation<double> animation;
  final double distance;
  final Curve move;
  final Curve fade;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Sempre a mesma árvore (com ou sem movimento): trocar o pai do
    // conteúdo recriaria o estado da tela.
    final moving = CurvedAnimation(parent: animation, curve: move);
    final out = CurvedAnimation(parent: animation, curve: fade);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final surface = context.nexoColors.surface;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final d = moving.value * distance;
        // Fundo Surface atrás da tela que sai, do mesmo tanto que ela some
        // (como o fillColor do SharedAxisTransition): aos 30%, quando as
        // duas telas estão transparentes, não aparece o que está atrás do
        // navegador. Começa transparente para o topo das abas não sumir de
        // uma vez.
        return ColoredBox(
          color: surface.withValues(alpha: out.value),
          child: Opacity(
            opacity: 1 - out.value,
            child: Transform.translate(
              offset: Offset(rtl ? d : -d, 0),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Minimizar o foco: ao fechar, a tela inteira encolhe e desce até o
/// retângulo de [target] (a Barra do foco), com os cantos arredondando até
/// `Shape/LG` e o conteúdo esmaecendo na primeira metade; no fim ela tem a
/// cor da barra, que aparece no lugar. Ao abrir (ou sem [target] na tela,
/// quando o foco foi encerrado), só repassa o [child] (subir/descer).
///
/// A árvore é a mesma com ou sem o encolhimento: trocar o pai da tela
/// recriaria o estado dela.
class _FocusMinimize extends StatefulWidget {
  const _FocusMinimize({
    required this.animation,
    required this.target,
    required this.child,
  });

  final Animation<double> animation;
  final GlobalKey? target;
  final Widget child;

  @override
  State<_FocusMinimize> createState() => _FocusMinimizeState();
}

class _FocusMinimizeState extends State<_FocusMinimize> {
  /// O retângulo da barra (nas coordenadas desta tela), lido ao começar a
  /// fechar. `null` = sem encolher.
  Rect? _to;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(_FocusMinimize oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_onStatus);
      widget.animation.addStatusListener(_onStatus);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.reverse) {
      if (status == AnimationStatus.forward && _to != null) {
        setState(() => _to = null);
      }
      return;
    }
    final bar = widget.target?.currentContext?.findRenderObject();
    final self = context.findRenderObject();
    Rect? to;
    if (bar is RenderBox &&
        self is RenderBox &&
        bar.attached &&
        bar.hasSize &&
        self.hasSize) {
      final origin = self.globalToLocal(bar.localToGlobal(Offset.zero));
      to = origin & bar.size;
    }
    setState(() => _to = to);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final radius = context.shape.lg;
    final curve = context.motion.emphasized;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final full = Offset.zero & size;
        return AnimatedBuilder(
          animation: widget.animation,
          builder: (context, child) {
            final to = _to;
            // 0 = tela inteira; 1 = do tamanho da barra.
            final p = to == null
                ? 0.0
                : curve.transform(1 - widget.animation.value);
            final rect = Rect.lerp(full, to ?? full, p)!;
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      lerpDouble(0, radius, p)!,
                    ),
                    child: ColoredBox(
                      color: to == null
                          ? Colors.transparent
                          : c.surfaceContainerLowest,
                      child: Opacity(
                        opacity: 1 - const Interval(0, 0.5).transform(p),
                        child: FittedBox(
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.topCenter,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox.fromSize(size: size, child: child),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          child: widget.child,
        );
      },
    );
  }
}
