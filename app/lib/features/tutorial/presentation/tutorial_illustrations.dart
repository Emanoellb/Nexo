import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/nexo_theme.dart';

/// Toca a animação de uma ilustração: do começo a cada mudança de [play]
/// enquanto [active]. Com "reduzir movimento", mostra direto o estado final.
class TutorialAnimation extends StatefulWidget {
  const TutorialAnimation({
    super.key,
    required this.play,
    required this.active,
    required this.duration,
    required this.builder,
    this.delay = Duration.zero,
  });

  final int play;
  final bool active;
  final Duration duration;

  /// Espera antes de tocar: a troca de página termina primeiro, para a
  /// animação não começar com a página ainda deslizando.
  final Duration delay;

  /// [t] vai de 0 a 1.
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<TutorialAnimation> createState() => _TutorialAnimationState();
}

class _TutorialAnimationState extends State<TutorialAnimation>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  Timer? _wait;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  void _start() {
    _wait?.cancel();
    if (_reduceMotion) {
      _controller.value = 1;
      return;
    }
    _controller.value = 0;
    _wait = Timer(widget.delay, () {
      if (mounted) _controller.forward(from: 0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      _controller.value = 1;
    } else if (widget.active &&
        widget.play > 0 &&
        _controller.value == 0 &&
        !_controller.isAnimating &&
        _wait == null) {
      _start();
    }
  }

  @override
  void didUpdateWidget(TutorialAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && widget.play != oldWidget.play) _start();
  }

  @override
  void dispose() {
    _wait?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => widget.builder(context, _controller.value),
  );
}

/// Fração de [t] entre [start] e [end], com [curve].
double _phase(double t, double start, double end, Curve curve) =>
    curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));

/// Entra subindo e aparecendo.
Widget _enter(BuildContext context, double p, Widget child) => Opacity(
  opacity: p,
  child: Transform.translate(
    offset: Offset(0, (1 - p) * context.motion.distanceMedium),
    child: child,
  ),
);

/// Largura de desenho das ilustrações; [_Stage] reduz para caber.
const _stageWidth = 300.0;

class _Stage extends StatelessWidget {
  const _Stage({required this.label, required this.child});

  /// Descrição para o leitor de tela.
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: true,
    child: ExcludeSemantics(
      // Largura fixa e altura do conteúdo; o conjunto encolhe para caber
      // (tela pequena ou fonte ampliada).
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(width: _stageWidth, child: child),
        ),
      ),
    ),
  );
}

/// Cartão branco das ilustrações.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    return Container(
      padding: padding ?? EdgeInsets.all(context.spacing.md),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(context.shape.md),
        border: Border.all(color: c.cardBorder),
      ),
      child: child,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.icon, this.emphasis = false});

  final String text;
  final IconData? icon;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final color = emphasis ? c.onPrimaryContainer : c.onSurface;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: emphasis ? c.primaryContainer : c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(context.shape.full),
        border: emphasis ? null : Border.all(color: c.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            SizedBox(width: spacing.xs),
          ],
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium!
                  .copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de progresso fina, preenchida até [value].
class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color, required this.track});

  final double value;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.shape.full);
    return Container(
      height: 8,
      decoration: BoxDecoration(color: track, borderRadius: radius),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(color: color, borderRadius: radius),
        ),
      ),
    );
  }
}

/// Passo 1: objetivo → tópicos do plano → meta diária.
class GoalPlanIllustration extends StatelessWidget {
  const GoalPlanIllustration({super.key, required this.t});

  final double t;

  static const topics = ['Português', 'Raciocínio lógico', 'Direito'];

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final motion = context.motion;
    final text = Theme.of(context).textTheme;
    return _Stage(
      label:
          'Objetivo Passar no Concurso Horizonte, com um plano de três '
          'tópicos e meta de 1 hora e 30 minutos por dia.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _enter(
            context,
            _phase(t, 0, 0.35, motion.enter),
            _Card(
              child: Row(
                children: [
                  Icon(LucideIcons.target, size: 24, color: c.primary),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Passar no Concurso Horizonte',
                          style: text.titleSmall!.copyWith(color: c.onSurface),
                        ),
                        Text(
                          'Prazo: dezembro de 2027',
                          style: text.bodySmall!.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.lg),
          Text(
            'Plano de ação',
            style: text.labelSmall!.copyWith(color: c.onSurfaceVariant),
          ),
          SizedBox(height: spacing.sm),
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: [
              for (var i = 0; i < topics.length; i++)
                _enter(
                  context,
                  _phase(t, 0.3 + i * 0.12, 0.6 + i * 0.12, motion.enter),
                  _Chip(topics[i]),
                ),
            ],
          ),
          SizedBox(height: spacing.md),
          _enter(
            context,
            _phase(t, 0.75, 1, motion.enter),
            const _Chip(
              '1h30 por dia',
              icon: LucideIcons.clock,
              emphasis: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Passo 2: dias planejados na semana (dom–sáb) e uma tarefa concluída.
class TasksCalendarIllustration extends StatelessWidget {
  const TasksCalendarIllustration({super.key, required this.t});

  final double t;

  static const _days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
  static const _planned = {1, 3, 5};

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final motion = context.motion;
    final text = Theme.of(context).textTheme;
    final done = _phase(t, 0.6, 0.8, motion.standard);

    Widget day(int i) {
      final planned = _planned.contains(i);
      final p = planned
          ? _phase(t, 0.1 + i * 0.06, 0.35 + i * 0.06, motion.standard)
          : 0.0;
      return SizedBox(
        width: 38,
        child: Column(
          children: [
            Text(
              _days[i],
              style: text.labelSmall!.copyWith(color: c.onSurfaceVariant),
            ),
            SizedBox(height: spacing.xs),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.lerp(
                  c.surfaceContainerLowest,
                  c.primaryContainer,
                  p,
                ),
                borderRadius: BorderRadius.circular(context.shape.sm),
              ),
              child: Text(
                '${9 + i}',
                style: text.labelMedium!.copyWith(color: c.onSurface),
              ),
            ),
            SizedBox(height: spacing.xs),
            Opacity(
              opacity: p,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: c.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget task(String title, String meta, {required double checked}) => _Card(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Color.lerp(c.surfaceContainerLowest, c.primary, checked),
              borderRadius: BorderRadius.circular(context.shape.xs),
              border: Border.all(
                width: 2,
                color: Color.lerp(c.controlBorder, c.primary, checked)!,
              ),
            ),
            child: Opacity(
              opacity: checked,
              child: Icon(LucideIcons.check, size: 14, color: c.onPrimary),
            ),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleSmall!.copyWith(color: c.onSurface),
                ),
                Text(
                  meta,
                  style: text.bodySmall!.copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return _Stage(
      label:
          'Semana de domingo a sábado com segunda, quarta e sexta planejadas, '
          'e a tarefa Lista de exercícios 4 sendo concluída.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (var i = 0; i < _days.length; i++) day(i)],
          ),
          SizedBox(height: spacing.lg),
          task(
            'Lista de exercícios 4',
            'Estatística · entrega na sexta',
            checked: done,
          ),
          SizedBox(height: spacing.sm),
          task(
            'Resumo para a prova',
            'Português · entrega em 1 semana',
            checked: 0,
          ),
        ],
      ),
    );
  }
}

/// Passo 3: o dia de hoje no Início, com a meta e o que focar agora.
class TodayIllustration extends StatelessWidget {
  const TodayIllustration({super.key, required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final motion = context.motion;
    final text = Theme.of(context).textTheme;
    final fill = _phase(t, 0.2, 0.75, motion.emphasized);
    final minutes = (60 * fill).round();

    return _Stage(
      label:
          'Hoje, terça: meta do dia com 60 de 90 minutos feitos e agora '
          'Raciocínio lógico.',
      child: _enter(
        context,
        _phase(t, 0, 0.3, motion.enter),
        _Card(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Hoje, terça',
                style: text.titleLarge!.copyWith(color: c.onSurface),
              ),
              SizedBox(height: spacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Meta do dia',
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall!.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '$minutes de 90 min',
                    style: text.bodySmall!.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              _Bar(
                value: fill * 60 / 90,
                color: c.primary,
                track: c.primaryContainer,
              ),
              SizedBox(height: spacing.lg),
              _enter(
                context,
                _phase(t, 0.7, 1, motion.enter),
                Row(
                  children: [
                    const _Chip('Agora', emphasis: true),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: Text(
                        'Raciocínio lógico',
                        style: text.titleSmall!.copyWith(color: c.onSurface),
                      ),
                    ),
                    Icon(LucideIcons.play, size: 20, color: c.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Passo 4: o cronômetro conta e o arco fecha.
class FocusIllustration extends StatelessWidget {
  const FocusIllustration({super.key, required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final text = Theme.of(context).textTheme;
    final p = _phase(t, 0, 1, context.motion.emphasized);
    final minutes = (25 * p).round();

    return _Stage(
      label: 'Sessão de foco de 25 minutos em Raciocínio lógico.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 170,
            child: CustomPaint(
              painter: _RingPainter(
                progress: p,
                color: c.primary,
                track: c.primaryContainer,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$minutes min',
                      style: text.headlineLarge!.copyWith(color: c.onSurface),
                    ),
                    Text(
                      'de foco',
                      style: text.bodySmall!.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: spacing.md),
          const _Chip('Raciocínio lógico', icon: LucideIcons.timer),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// Passo 5: horas planejadas × realizadas e os pontos subindo o nível.
/// Progresso usa Secondary (regra do design system).
class ProgressIllustration extends StatelessWidget {
  const ProgressIllustration({super.key, required this.t});

  final double t;

  static const _days = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
  static const _planned = [0, 90, 60, 90, 60, 90, 30];
  static const _done = [0, 90, 45, 100, 60, 70, 30];

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final motion = context.motion;
    final text = Theme.of(context).textTheme;
    final grow = _phase(t, 0, 0.6, motion.emphasized);
    final scored = _phase(t, 0.65, 0.9, motion.standard);
    // Nível 2 vai de 20 a 39 pontos (nível = pontos ÷ 20 + 1).
    final points = scored < 0.5 ? 37 : 38;
    final level = (17 + scored) / 20;

    Widget bar(double minutes, Color color) => Container(
      width: 10,
      // Até 72 px: sobra lugar para o rótulo do dia com fonte ampliada.
      height: 72 * minutes / 100 * grow,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(context.shape.xs),
      ),
    );

    return _Stage(
      label:
          'Gráfico da semana com horas planejadas e realizadas, e nível 2 com '
          '38 pontos; o próximo nível é com 40.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < _days.length; i++)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          bar(_planned[i].toDouble(), c.secondaryContainer),
                          const SizedBox(width: 3),
                          bar(_done[i].toDouble(), c.secondary),
                        ],
                      ),
                      SizedBox(height: spacing.xs),
                      Text(
                        _days[i],
                        style: text.labelSmall!.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          SizedBox(height: spacing.md),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Nível 2',
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall!.copyWith(color: c.onSurface),
                      ),
                    ),
                    Text(
                      '$points pontos',
                      style: text.labelMedium!.copyWith(color: c.secondary),
                    ),
                  ],
                ),
                SizedBox(height: spacing.sm),
                _Bar(
                  value: level,
                  color: c.secondary,
                  track: c.secondaryContainer,
                ),
                SizedBox(height: spacing.xs),
                Text(
                  'Próximo nível: 40',
                  style: text.bodySmall!.copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
