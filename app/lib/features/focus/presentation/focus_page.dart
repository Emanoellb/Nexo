import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/data/clock.dart';
import '../../../core/data/local_flags.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/format/duration_text.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../auth/application/auth_providers.dart';
import '../../plans/application/plans_providers.dart';
import '../../tasks/presentation/task_text.dart';
import '../application/focus_controller.dart';
import '../application/focus_system.dart';
import '../domain/active_focus.dart';
import '../domain/session_split.dart';
import 'session_topics.dart';

/// "Pausado há 3 min" / "Pausado há 1h 05min" / "Pausado agora".
String pausedText(DateTime since, DateTime now) {
  final minutes = now.difference(since).inMinutes;
  return minutes < 1 ? 'Pausado agora' : 'Pausado há ${formatMinutes(minutes)}';
}

/// Foco em tela cheia (pedido do usuário, 09/11/2026): ao abrir, só o
/// relógio; tocar mostra as ações. `false` deixa tudo sempre à mostra (os
/// testes dos fluxos usam assim).
final focusImmersiveProvider = Provider<bool>((ref) => true);

/// Foco (design de 07/11/2026, telas 01–07): o plano, o cronômetro, os
/// tópicos (até 3), o "Não perturbe" (quando o aparelho permite) e as ações
/// grandes no rodapé (Fitts): Pausar e Encerrar, ou Encerrar e Retomar.
///
/// A seta para baixo e o voltar do Android **minimizam**: o tempo continua
/// e a Barra do foco aparece acima das abas. Nunca encerram.
///
/// Tela cheia (decisões do usuário, 09/11/2026): ao abrir, só o relógio, no
/// centro da tela, com as barras do Android escondidas. Um toque em
/// qualquer lugar mostra o topo, o plano, o rótulo, o total do dia, os
/// tópicos e as ações; somem de novo após 5 s sem toque (pausado também).
/// As partes escondidas só ficam transparentes, no mesmo lugar: o relógio
/// não pula. Com o leitor de tela, tudo fica sempre à mostra.
class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage>
    with LeaveOnce<FocusPage> {
  ActiveFocusNotifier get _focus => ref.read(activeFocusProvider.notifier);

  /// Quanto as ações ficam à mostra depois do último toque.
  static const controlsTimeout = Duration(seconds: 5);

  /// As ações estão à mostra (tela cheia: começa só com o relógio).
  bool _controls = false;
  Timer? _hideTimer;

  /// A tela cheia vale agora (ligada e sem leitor de tela).
  bool _immersive = false;

  @override
  void dispose() {
    _hideTimer?.cancel();
    _systemBars(visible: true);
    super.dispose();
  }

  /// Barras do Android: escondidas só com as ações escondidas.
  void _systemBars({required bool visible}) =>
      SystemChrome.setEnabledSystemUIMode(
        visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
      );

  /// Qualquer toque: mostra as ações e reinicia os 5 s.
  void _onTouch() {
    if (!_immersive) return;
    if (!_controls) {
      setState(() => _controls = true);
      _systemBars(visible: true);
    }
    _hideTimer?.cancel();
    _hideTimer = Timer(controlsTimeout, _hideControls);
  }

  void _hideControls() {
    if (!mounted || !_immersive) return;
    // Com um painel ou menu por cima, espera ele fechar.
    if (ModalRoute.of(context)?.isCurrent == false) {
      _hideTimer = Timer(controlsTimeout, _hideControls);
      return;
    }
    setState(() => _controls = false);
    _systemBars(visible: false);
  }

  void _minimize() {
    _systemBars(visible: true);
    leave();
  }

  Future<void> _finish(ActiveFocus focus) async {
    final now = ref.read(clockProvider)();
    final actions = ref.read(focusActionsProvider);
    if (focus.elapsed(now) < ActiveFocus.minimum) {
      final result = await actions.finish(topicIds: focus.topicIds);
      if (!mounted || result is! FocusTooShort) return;
      final notifier = _focus;
      showNexoSnackbar(
        context,
        message: 'Sessão muito curta para salvar.',
        tone: NexoSnackbarTone.info,
        actionLabel: 'Desfazer',
        onAction: () => notifier.restore(result.focus),
      );
      leave();
      return;
    }
    // O tempo para enquanto o painel está aberto; fechar sem decidir
    // continua de onde estava.
    final wasRunning = !focus.isPaused;
    if (wasRunning) await _focus.pause();
    if (!mounted) return;
    // Lido uma vez: o painel é reconstruído na saída, quando o foco já
    // foi limpo pelo salvar.
    final paused = ref.read(activeFocusProvider);
    if (paused == null) return;
    final decision = await showNexoBottomSheet<_EndDecision>(
      context,
      title: 'Encerrar sessão',
      builder: (_) => _EndSessionForm(focus: paused),
    );
    if (!mounted) return;
    switch (decision) {
      case null:
        if (wasRunning) await _focus.resume();
      case _Discard():
        final kept = ref.read(activeFocusProvider)!;
        final notifier = _focus;
        await notifier.clear();
        if (!mounted) return;
        showNexoSnackbar(
          context,
          message: 'Sessão descartada.',
          actionLabel: 'Desfazer',
          onAction: () => notifier.restore(kept),
        );
        leave();
      case _Save(:final topicIds, :final note):
        final result = await actions.finish(topicIds: topicIds, note: note);
        if (!mounted || result is! FocusSaved) return;
        final message = result.metGoalNow
            ? 'Sessão salva · +${formatMinutes(result.minutes)}. Meta do dia '
                  'batida!'
            : 'Sessão salva · +${formatMinutes(result.minutes)}.';
        showNexoSnackbar(
          context,
          message: message,
          tone: NexoSnackbarTone.success,
          actionLabel: 'Desfazer',
          onAction: () => actions.undoSave(result),
          // Na fila: se a sessão concluir os "Primeiros passos", o aviso do
          // Início vem antes.
          queue: true,
        );
        leave();
    }
  }

  /// Ligar o "Não perturbe": o painel do Nexo (tela 03) pergunta, a não
  /// ser que a conta já tenha escolhido "Permitir durante o uso do app".
  /// Sem o acesso do sistema, abre a tela dele (uma vez só) e espera a
  /// volta ao app.
  Future<void> _toggleDnd({required bool on}) async {
    if (!on) return _focus.setDnd(on: false);
    final system = ref.read(focusSystemProvider);
    final flags = ref.read(localFlagsProvider);
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    if (!flags.dndAllowed(uid)) {
      final choice = await showDndPermissionSheet(context);
      if (choice == null || choice == DndChoice.deny || !mounted) return;
      if (choice == DndChoice.always) await flags.setDndAllowed(uid);
    }
    if (!await system.dndAccessGranted() && !await system.openDndSettings()) {
      return;
    }
    if (mounted) await _focus.setDnd(on: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final focus = ref.watch(activeFocusProvider);
    if (focus == null) {
      // Encerrado em outro lugar (ou já saindo): sai.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) leave();
      });
      return const Scaffold(body: SizedBox.expand());
    }
    final now = ref.watch(focusNowProvider).value ?? ref.read(clockProvider)();
    final plan = ref.watch(planProvider(focus.planId)).value;
    final today = ref.watch(focusPlanTodayProvider);
    final elapsed = focus.elapsed(now);
    final paused = focus.isPaused;

    // Hoje: o que já estava gravado + a parte de hoje desta sessão.
    final dayStart = LocalDate.fromDateTime(now).startOfDay;
    final todayLive = splitSessionByDay(focus.intervals(now))
        .where((s) => !s.startAt.isBefore(dayStart))
        .fold(0, (sum, s) => sum + s.durationSeconds ~/ 60);
    final done = (today?.today.doneMinutes ?? 0) + todayLive;
    final goal = today?.today.goalMinutes ?? 0;
    final dayTotal = goal > 0
        ? 'Hoje: ${formatMinutes(done)} de ${formatMinutes(goal)}'
        : 'Hoje: ${formatMinutes(done)}';
    final system = ref.watch(focusSystemProvider);

    final pause = NexoButton.secondary(
      label: 'Pausar',
      leadingIcon: LucideIcons.pause,
      expand: true,
      onPressed: _focus.pause,
    );
    final end = paused
        ? NexoButton.secondary(
            label: 'Encerrar',
            leadingIcon: LucideIcons.square,
            expand: true,
            onPressed: () => _finish(focus),
          )
        : NexoButton.primary(
            label: 'Encerrar',
            leadingIcon: LucideIcons.square,
            expand: true,
            onPressed: () => _finish(focus),
          );
    final resume = NexoButton.primary(
      label: 'Retomar',
      leadingIcon: LucideIcons.play,
      expand: true,
      onPressed: _focus.resume,
    );

    // Tela cheia: ligada e sem leitor de tela (ações escondidas ficariam
    // fora do alcance dele).
    final immersive =
        ref.watch(focusImmersiveProvider) &&
        !MediaQuery.accessibleNavigationOf(context);
    if (immersive != _immersive) {
      _immersive = immersive;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _systemBars(visible: !_immersive || _controls);
      });
    }
    final show = !immersive || _controls;
    final reduce = MediaQuery.disableAnimationsOf(context);
    Widget chrome(Widget child) => AnimatedOpacity(
      opacity: show ? 1 : 0,
      duration: reduce ? Duration.zero : context.motion.short,
      curve: context.motion.standard,
      child: IgnorePointer(
        ignoring: !show,
        child: ExcludeSemantics(excluding: !show, child: child),
      ),
    );

    return Listener(
      // Qualquer toque (inclusive nas ações) mostra e reinicia os 5 s.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onTouch(),
      child: Scaffold(
        // O relógio fica no centro da tela inteira: o topo e o rodapé passam
        // por cima e somem sem mexer nele.
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: _ChromeAppBar(
          bar: NexoTopAppBar(
            title: 'Foco',
            minimizeIcon: true,
            onBack: _minimize,
          ),
          wrap: chrome,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.xl,
            ),
            child: ConstrainedBox(
              // A largura toda: o conteúdo centraliza na tela, não à
              // esquerda (bug de 09/11/2026).
              constraints: const BoxConstraints(minWidth: double.infinity),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  chrome(
                    Text(
                      plan?.name ?? '',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium!
                          .copyWith(color: c.onSurfaceVariant),
                    ),
                  ),
                  SizedBox(height: spacing.xl),
                  NexoFocusTimer(
                    label: paused
                        ? pausedText(focus.pausedSince!, now)
                        : 'Sessão de foco',
                    elapsed: elapsed,
                    dayTotal: dayTotal,
                    dayProgress: goal > 0 ? done / goal : null,
                    paused: paused,
                    showDetails: show,
                  ),
                  SizedBox(height: spacing.xl),
                  chrome(
                    SessionTopicsField(
                      planId: focus.planId,
                      topicIds: focus.topicIds,
                      center: true,
                      onChanged: _focus.setTopics,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // O rodapé (Pausar e Encerrar) fica no lugar da barra: a Snackbar
        // flutuante aparece acima dele, não por cima (decisão travada).
        bottomNavigationBar: chrome(
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.lg,
                spacing.sm,
                spacing.lg,
                spacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (system.supportsDnd) ...[
                    NexoSwitch(
                      label: 'Não perturbe',
                      helper: focus.dnd
                          ? 'Ligado: o celular fica em silêncio até você '
                                'encerrar.'
                          : 'Silencia o celular até você encerrar.',
                      value: focus.dnd,
                      onChanged: (on) => _toggleDnd(on: on),
                    ),
                    SizedBox(height: spacing.lg),
                  ],
                  Row(
                    children: [
                      Expanded(child: paused ? end : pause),
                      SizedBox(width: spacing.md),
                      Expanded(child: paused ? resume : end),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// O que o painel "Encerrar sessão" devolve.
sealed class _EndDecision {
  const _EndDecision();
}

final class _Save extends _EndDecision {
  const _Save(this.topicIds, this.note);

  final List<String> topicIds;
  final String? note;
}

final class _Discard extends _EndDecision {
  const _Discard();
}

/// Painel "Encerrar sessão" (telas 05 e 06): a duração líquida, o plano com
/// o horário e as pausas, o aviso de meia-noite (a sessão vira duas), os
/// tópicos, a nota e Salvar ou Descartar.
class _EndSessionForm extends ConsumerStatefulWidget {
  const _EndSessionForm({required this.focus});

  final ActiveFocus focus;

  @override
  ConsumerState<_EndSessionForm> createState() => _EndSessionFormState();
}

class _EndSessionFormState extends ConsumerState<_EndSessionForm> {
  late List<String> _topics = widget.focus.topicIds;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final focus = widget.focus;
    // Pausado ao abrir o painel: o fim é o começo da pausa.
    final now = ref.read(clockProvider)();
    final end = focus.pausedSince ?? now;
    final plan = ref.watch(planProvider(focus.planId)).value;
    final segments = splitSessionByDay(focus.intervals(end));
    final minutes = focus.elapsed(end).inMinutes;
    // A pausa em aberto começou no fim: não soma.
    final pausedMinutes = focus.pausedUntil(end).inMinutes;
    final start = focus.startedAt;
    final crossed = segments.length > 1;
    final when = crossed
        ? '${hhmm(start)}–${hhmm(end)}'
        : '${relativeDayText(LocalDate.fromDateTime(start), LocalDate.fromDateTime(now))}, ${hhmm(start)}–${hhmm(end)}';
    final line = [
      ?plan?.name,
      when,
      if (pausedMinutes > 0) '${formatMinutes(pausedMinutes)} de pausa',
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            formatMinutes(minutes),
            style: textTheme.headlineMedium!.copyWith(color: c.onSurface),
          ),
          SizedBox(height: spacing.xs),
          Text(
            line,
            style: textTheme.bodyMedium!.copyWith(color: c.onSurfaceVariant),
          ),
          if (crossed) ...[
            SizedBox(height: spacing.md),
            NexoAlert(
              tone: NexoAlertTone.info,
              icon: LucideIcons.moon,
              title: 'Passou da meia-noite',
              message:
                  'Fica ${[for (final s in segments) '${formatMinutes(s.durationSeconds ~/ 60)} em ${weekdayShortLower(s.day)}, ${s.day.day}/${s.day.month}'].join(' e ')}.',
            ),
          ],
          SizedBox(height: spacing.lg),
          Semantics(
            header: true,
            child: Text(
              'Tópicos',
              style: textTheme.labelMedium!.copyWith(color: c.onSurface),
            ),
          ),
          SizedBox(height: spacing.sm),
          SessionTopicsField(
            planId: focus.planId,
            topicIds: _topics,
            helper:
                'Opcional · até 3. As horas são divididas igualmente entre '
                'eles.',
            onChanged: (ids) => setState(() => _topics = ids),
          ),
          SizedBox(height: spacing.lg),
          NexoTextField(
            label: 'Nota',
            hintText: 'Ex.: Revisei crase e regência.',
            helperText: 'Opcional · até 500 caracteres.',
            controller: _note,
            minLines: 2,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(500)],
          ),
          SizedBox(height: spacing.lg),
          NexoButton.primary(
            label: 'Salvar sessão',
            leadingIcon: LucideIcons.check,
            expand: true,
            onPressed: () {
              final note = _note.text.trim();
              Navigator.of(context)
                  .pop(_Save(_topics, note.isEmpty ? null : note));
            },
          ),
          SizedBox(height: spacing.sm),
          NexoButton.destructiveLow(
            label: 'Descartar sessão',
            expand: true,
            onPressed: () => Navigator.of(context).pop(const _Discard()),
          ),
        ],
      ),
    );
  }
}

/// Opções do painel "Silenciar o celular no foco?" (tela 03).
enum DndChoice { always, once, deny }

/// Painel do Nexo antes de pedir o acesso ao "Não perturbe" (o Android não
/// tem uma janela de permissão comum para isso).
Future<DndChoice?> showDndPermissionSheet(BuildContext context) =>
    showNexoBottomSheet<DndChoice>(
      context,
      title: 'Silenciar o celular no foco?',
      builder: (sheetContext) {
        final spacing = sheetContext.spacing;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Para silenciar notificações e chamadas durante o foco, o Nexo '
                'precisa do acesso ao “Não perturbe”. Ao encerrar, o celular '
                'volta como estava.',
                style: Theme.of(sheetContext).textTheme.bodyMedium!
                    .copyWith(color: sheetContext.nexoColors.onSurfaceVariant),
              ),
              SizedBox(height: spacing.sm),
              // Risco aprovado em 09/11/2026: se o Android fechar o app à
              // força, o modo só é desligado na próxima abertura.
              Text(
                'O “Não perturbe” é desligado quando você encerra o foco ou '
                'reabre o app.',
                style: Theme.of(sheetContext).textTheme.bodySmall!
                    .copyWith(color: sheetContext.nexoColors.onSurfaceVariant),
              ),
              SizedBox(height: spacing.lg),
              NexoButton.primary(
                label: 'Permitir durante o uso do app',
                expand: true,
                onPressed: () =>
                    Navigator.of(sheetContext).pop(DndChoice.always),
              ),
              SizedBox(height: spacing.sm),
              NexoButton.secondary(
                label: 'Apenas esta vez',
                expand: true,
                onPressed: () => Navigator.of(sheetContext).pop(DndChoice.once),
              ),
              SizedBox(height: spacing.sm),
              NexoButton.tertiary(
                label: 'Não permitir',
                expand: true,
                onPressed: () => Navigator.of(sheetContext).pop(DndChoice.deny),
              ),
            ],
          ),
        );
      },
    );

/// O topo do Foco, que some na tela cheia sem mudar de tamanho.
class _ChromeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChromeAppBar({required this.bar, required this.wrap});

  final NexoTopAppBar bar;
  final Widget Function(Widget) wrap;

  @override
  Size get preferredSize => bar.preferredSize;

  @override
  Widget build(BuildContext context) => wrap(bar);
}
