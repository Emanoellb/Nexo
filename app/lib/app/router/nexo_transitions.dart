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
    NexoPageMotion motion,
  ) => NexoTransitionPage(
    key: state.pageKey,
    name: state.name ?? state.path,
    arguments: state.extra,
    restorationId: state.pageKey.value,
    child: child,
    motion: motion,
    tokens: context.motion,
    reduceMotion: MediaQuery.disableAnimationsOf(context),
  );

  final Widget child;
  final NexoPageMotion motion;
  final NexoMotion tokens;
  final bool reduceMotion;

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
    return page.motion == NexoPageMotion.fadeLong
        ? page.tokens.long
        : page.tokens.medium;
  }

  @override
  Duration get reverseTransitionDuration {
    final page = _page;
    if (page.reduceMotion || page.motion == NexoPageMotion.none) {
      return Duration.zero;
    }
    return page.motion == NexoPageMotion.fadeLong
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
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final d = moving.value * distance;
        return Opacity(
          opacity: 1 - out.value,
          child: Transform.translate(
            offset: Offset(rtl ? d : -d, 0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
