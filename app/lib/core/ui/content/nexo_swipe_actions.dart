import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../theme/nexo_theme.dart';

/// Uma ação de [NexoSwipeActions].
@immutable
class NexoSwipeAction {
  const NexoSwipeAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTrigger,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTrigger;
}

/// Deslizar numa linha (design de Tarefas, 04/11/2026; segue as ações de
/// deslizar da HIG):
/// - rumo ao fim da linha (à direita em pt-BR), [startAction] (ex.:
///   Concluir, fundo Success): soltar depois de 35% da largura dispara;
/// - rumo ao começo (à esquerda), revela [endActions] (ex.: Adiar e
///   Excluir), cada uma com 80 de largura e a altura da linha; tocar
///   dispara e fecha. Em idioma da direita para a esquerda, espelha.
///
/// As mesmas ações ficam no leitor de tela como ações personalizadas (sem
/// precisar arrastar). Com "reduzir movimento", abre e fecha sem animação.
/// [surface] é o fundo da linha (cobre as ações enquanto fechada).
class NexoSwipeActions extends StatefulWidget {
  const NexoSwipeActions({
    super.key,
    required this.child,
    this.startAction,
    this.endActions = const [],
    this.surface,
  });

  /// Largura de cada ação revelada à esquerda.
  static const double actionWidth = 80;

  /// Fração da largura que dispara a ação da direita.
  static const double triggerFraction = 0.35;

  final Widget child;
  final NexoSwipeAction? startAction;
  final List<NexoSwipeAction> endActions;

  /// Padrão: Card/Default.
  final Color? surface;

  @override
  State<NexoSwipeActions> createState() => _NexoSwipeActionsState();
}

class _NexoSwipeActionsState extends State<NexoSwipeActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addListener(() => setState(() => _dx = _animation!.value));

  /// Uma curva só, trocada a cada animação (criar uma por animação deixaria
  /// ouvintes presos ao controller).
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.linear,
  );
  Animation<double>? _animation;

  /// Deslocamento lógico: positivo = rumo ao fim da linha (revela a ação de
  /// início); negativo = rumo ao começo (revela as ações do fim). Em idioma
  /// da direita para a esquerda, o visual é espelhado ([_sign]).
  double _dx = 0;
  double _width = 0;

  double get _sign => Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  double get _panel => NexoSwipeActions.actionWidth * widget.endActions.length;

  bool get _open => _dx < 0 && _dx <= -_panel + 1;

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    final motion = context.motion;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      setState(() => _dx = target);
      return;
    }
    _curve.curve = motion.standard;
    _animation = Tween<double>(begin: _dx, end: target).animate(_curve);
    _controller
      ..duration = motion.short
      ..forward(from: 0);
  }

  void _onUpdate(DragUpdateDetails details) {
    _controller.stop();
    final maxRight = widget.startAction == null ? 0.0 : _width * 0.6;
    final maxLeft = widget.endActions.isEmpty ? 0.0 : -_panel * 1.2;
    setState(() {
      _dx = (_dx + details.delta.dx * _sign).clamp(maxLeft, maxRight);
    });
  }

  void _onEnd(DragEndDetails details) {
    final velocity = (details.primaryVelocity ?? 0) * _sign;
    final start = widget.startAction;
    if (_dx > 0) {
      final fired =
          start != null &&
          (_dx > _width * NexoSwipeActions.triggerFraction || velocity > 900);
      _animateTo(0);
      if (fired) start.onTrigger();
      return;
    }
    final open = _dx < -_panel / 2 || velocity < -900;
    _animateTo(open && widget.endActions.isNotEmpty ? -_panel : 0);
  }

  void _trigger(NexoSwipeAction action) {
    _animateTo(0);
    action.onTrigger();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final start = widget.startAction;
    // Design (Tarefas 07): ações do fim com ícone sobre o rótulo
    // (LabelSmall 600, 2 entre eles); Concluir com ícone e rótulo lado a
    // lado (LabelMedium 600, SM entre eles).
    Widget endContent(NexoSwipeAction a) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(a.icon, size: 20, color: a.foreground),
        SizedBox(height: spacing.xxs),
        Text(
          a.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context
              .textStyle(NexoTextStyles.labelSmallEmphasis)
              .copyWith(color: a.foreground),
        ),
      ],
    );

    Widget startContent(NexoSwipeAction a) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(a.icon, size: 20, color: a.foreground),
        SizedBox(width: spacing.sm),
        Text(
          a.label,
          maxLines: 1,
          style: context
              .textStyle(NexoTextStyles.labelMediumEmphasis)
              .copyWith(color: a.foreground),
        ),
      ],
    );

    // Um nó por linha: as ações ficam nesta tarefa, nunca no cartão inteiro.
    return Semantics(
      container: true,
      customSemanticsActions: {
        if (start != null)
          CustomSemanticsAction(label: start.label): start.onTrigger,
        for (final a in widget.endActions)
          CustomSemanticsAction(label: a.label): a.onTrigger,
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _width = constraints.maxWidth;
          return ClipRect(
            child: Stack(
              children: [
                // Fundo da ação de início (Concluir).
                if (_dx > 0 && start != null)
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: ColoredBox(
                        color: start.background,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Padding(
                            // Design: 20 (LG + XS) da borda.
                            padding: EdgeInsetsDirectional.only(
                              start: spacing.lg + spacing.xs,
                            ),
                            child: startContent(start),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Ações reveladas no fim da linha (Adiar, Excluir).
                if (_dx < 0)
                  PositionedDirectional(
                    top: 0,
                    bottom: 0,
                    end: 0,
                    width: _panel,
                    child: Row(
                      children: [
                        for (final a in widget.endActions)
                          Expanded(
                            child: Semantics(
                              button: true,
                              label: a.label,
                              onTap: () => _trigger(a),
                              excludeSemantics: true,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _trigger(a),
                                child: ColoredBox(
                                  color: a.background,
                                  child: Center(child: endContent(a)),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                GestureDetector(
                  onHorizontalDragUpdate: _onUpdate,
                  onHorizontalDragEnd: _onEnd,
                  // Aberta: tocar na linha fecha (sem agir na linha).
                  onTap: _open ? () => _animateTo(0) : null,
                  child: Transform.translate(
                    offset: Offset(_dx * _sign, 0),
                    child: AbsorbPointer(
                      absorbing: _open,
                      child: ColoredBox(
                        color: widget.surface ?? c.cardDefault,
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
