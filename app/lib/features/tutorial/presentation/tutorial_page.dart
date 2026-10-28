import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/brand/nexo_animated_symbol.dart';
import '../../../core/ui/ui.dart';
import '../../auth/application/auth_providers.dart';
import '../application/tutorial_controller.dart';
import 'tutorial_illustrations.dart';

/// Conteúdo de um passo.
class _Step {
  const _Step(this.title, this.body, this.illustration);

  final String title;
  final String body;
  final Widget Function(double t) illustration;
}

final _steps = [
  _Step(
    'Objetivo e plano',
    'Defina aonde quer chegar, divida em tópicos e escolha quanto tempo '
        'dedicar por dia.',
    (t) => GoalPlanIllustration(t: t),
  ),
  _Step(
    'Tarefas e calendário',
    'Organize disciplinas, entregas e prazos. Cada dia mostra o que você '
        'planejou.',
    (t) => TasksCalendarIllustration(t: t),
  ),
  _Step(
    'Seu dia no Início',
    'Veja o que fazer hoje e no que focar agora.',
    (t) => TodayIllustration(t: t),
  ),
  _Step(
    'Sessão de foco',
    'Cronometre cada sessão e ela entra no seu plano.',
    (t) => FocusIllustration(t: t),
  ),
  _Step(
    'Seu progresso',
    'Compare horas planejadas e realizadas. Tarefas e dias cumpridos somam '
        'pontos e sobem seu nível.',
    (t) => ProgressIllustration(t: t),
  ),
];

/// Tela 06 Boas-vindas + tutorial (roteiro de 26/10/2026, com o "Tudo
/// pronto" de 28/10): 5 passos e a tela de fechamento. "Pular" leva ao
/// fechamento; "Começar" grava `tutorialSeen` e o roteador segue ao Início.
class TutorialPage extends ConsumerStatefulWidget {
  const TutorialPage({super.key});

  /// Duração da animação de cada ilustração. Era 600 ms (roteiro: 300–600
  /// ms); o usuário pediu mais lenta em 28/10/2026 para ver a animação toda.
  static const illustrationDuration = Duration(milliseconds: 1800);

  /// Símbolo + textos do "Tudo pronto".
  static const doneDuration = Duration(milliseconds: 2200);

  @override
  ConsumerState<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends ConsumerState<TutorialPage> {
  final _pages = PageController();

  /// Navegação pelos botões em andamento: as páginas do meio não contam como
  /// "entrou na página" (ex.: "Pular" do passo 1 ao fechamento).
  bool _byButton = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _goTo(int page) async {
    _byButton = true;
    try {
      if (MediaQuery.disableAnimationsOf(context)) {
        _pages.jumpToPage(page);
      } else {
        await _pages.animateToPage(
          page,
          duration: context.motion.long,
          curve: context.motion.standard,
        );
      }
    } finally {
      _byButton = false;
    }
  }

  void _onPageChanged(int page) {
    if (_byButton) return;
    ref.read(tutorialControllerProvider.notifier).showPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tutorialControllerProvider);
    final controller = ref.read(tutorialControllerProvider.notifier);
    final name = ref.watch(userProfileProvider).value?.displayName;
    final c = context.nexoColors;
    final spacing = context.spacing;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // O estado manda na página (botões); o gesto atualiza o estado.
    ref.listen(tutorialControllerProvider.select((s) => s.page), (_, page) {
      if (_pages.hasClients && _pages.page?.round() != page) _goTo(page);
    });

    return PopScope(
      // Voltar do Android: passo anterior; no 1º passo, sai do app.
      canPop: state.page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.previous();
      },
      child: Scaffold(
        backgroundColor: c.surface,
        body: SafeArea(
          child: Column(
            children: [
              // Topo: logo e "Pular" (some no "Tudo pronto").
              Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.lg,
                  spacing.xl,
                  spacing.xs,
                  0,
                ),
                child: SizedBox(
                  height: 48,
                  child: state.isDone
                      ? null
                      : Row(
                          children: [
                            const NexoWordmark(height: 24),
                            const Spacer(),
                            NexoButton.tertiary(
                              label: 'Pular',
                              onPressed: controller.skip,
                            ),
                          ],
                        ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: _onPageChanged,
                  children: [
                    for (var i = 0; i < _steps.length; i++)
                      _StepPage(
                        step: _steps[i],
                        greeting: i == 0 && name != null
                            ? 'Boas-vindas, $name'
                            : null,
                        play: state.playsOf(i),
                        active: state.page == i,
                        onReplay: reduceMotion ? null : controller.replay,
                      ),
                    _DonePage(
                      play: state.playsOf(TutorialSteps.done),
                      active: state.isDone,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.lg,
                  spacing.md,
                  spacing.lg,
                  spacing.xl,
                ),
                child: state.isDone
                    ? NexoButton.primary(
                        label: 'Começar',
                        expand: true,
                        loading: state.finishing,
                        onPressed: controller.finish,
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          NexoPageControl(
                            count: TutorialSteps.count,
                            index: state.page,
                          ),
                          SizedBox(height: spacing.sm),
                          // Com fonte muito grande, os rótulos encurtam em
                          // vez de estourar.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Sem "Voltar" no 1º passo.
                              if (state.page > 0)
                                Flexible(
                                  child: NexoButton.tertiary(
                                    label: 'Voltar',
                                    leadingIcon: LucideIcons.arrowLeft,
                                    onPressed: controller.previous,
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                              Flexible(
                                child: NexoButton.primary(
                                  label: 'Próximo',
                                  trailingIcon: LucideIcons.arrowRight,
                                  onPressed: controller.next,
                                ),
                              ),
                            ],
                          ),
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

class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.step,
    required this.play,
    required this.active,
    required this.onReplay,
    this.greeting,
  });

  final _Step step;
  final String? greeting;
  final int play;
  final bool active;

  /// `null` com "reduzir movimento": sem animação, sem o botão.
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final text = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: spacing.md),
            // Ilustração com até metade da altura disponível.
            SizedBox(
              height: (constraints.maxHeight * 0.55).clamp(200.0, 380.0),
              child: Container(
                decoration: BoxDecoration(
                  color: c.surfaceContainer,
                  borderRadius: BorderRadius.circular(context.shape.lg),
                ),
                padding: EdgeInsets.all(spacing.lg),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: TutorialAnimation(
                        play: play,
                        active: active,
                        duration: TutorialPage.illustrationDuration,
                        delay: context.motion.long,
                        builder: (context, t) => step.illustration(t),
                      ),
                    ),
                    if (onReplay != null)
                      Positioned(
                        top: -spacing.md,
                        right: -spacing.md,
                        child: NexoIconButton(
                          icon: LucideIcons.rotateCcw,
                          tooltip: 'Repetir animação',
                          iconSize: 20,
                          onPressed: onReplay,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.xl),
            if (greeting != null) ...[
              Text(
                greeting!,
                style: text.labelMedium!.copyWith(color: c.primary),
              ),
              SizedBox(height: spacing.xs),
            ],
            Semantics(
              header: true,
              child: Text(
                step.title,
                style: text.headlineMedium!.copyWith(color: c.onSurface),
              ),
            ),
            SizedBox(height: spacing.sm),
            Text(
              step.body,
              style: text.bodyLarge!.copyWith(color: c.onSurfaceVariant),
            ),
            SizedBox(height: spacing.lg),
          ],
        ),
      ),
    );
  }
}

/// Fechamento "Tudo pronto": o símbolo se desenha e os textos entram.
class _DonePage extends StatelessWidget {
  const _DonePage({required this.play, required this.active});

  final int play;
  final bool active;

  static double _phase(double t, double start, double end, Curve curve) =>
      curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final motion = context.motion;
    final text = Theme.of(context).textTheme;

    return TutorialAnimation(
      play: play,
      active: active,
      duration: TutorialPage.doneDuration,
      delay: context.motion.long,
      builder: (context, t) {
        final words = _phase(t, 0.55, 0.9, motion.enter);
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'Nexo',
                  image: true,
                  child: NexoAnimatedSymbol(
                    size: 112,
                    straight: _phase(t, 0, 0.35, motion.emphasized),
                    curve: _phase(t, 0.22, 0.65, motion.emphasized),
                  ),
                ),
                SizedBox(height: spacing.xl),
                Opacity(
                  opacity: words,
                  child: Transform.translate(
                    offset: Offset(0, (1 - words) * motion.distanceMedium),
                    child: Column(
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Tudo pronto',
                            textAlign: TextAlign.center,
                            style: text.headlineLarge!.copyWith(
                              color: c.onSurface,
                            ),
                          ),
                        ),
                        SizedBox(height: spacing.sm),
                        Text(
                          'Seu objetivo e a ação do dia, no mesmo lugar.',
                          textAlign: TextAlign.center,
                          style: text.bodyLarge!.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
