import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/local_flags.dart';
import '../../core/ui/ui.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/focus/application/focus_controller.dart';
import '../../features/progress/application/achievements_providers.dart';
import '../../features/focus/application/focus_system.dart';
import '../../features/focus/presentation/shell_focus_bar.dart';
import '../../features/notifications/application/local_notices.dart';
import '../../features/notifications/application/notifications_providers.dart';
import '../../features/notifications/domain/local_notice.dart';
import '../../features/plans/application/plans_providers.dart';
import '../../features/tasks/application/tasks_providers.dart';
import '../../features/notifications/domain/nexo_notification.dart';
import '../../features/notifications/presentation/notifications_panel.dart';
import '../router/routes.dart';
import 'tab_root.dart';

/// "Reduzir transparência": troca o vidro da barra pela versão sólida.
/// O Android não expõe essa preferência ao Flutter [NC]: é um ajuste do app,
/// no Perfil, guardado só no aparelho. Começa desligada.
final reduceTransparencyProvider = NotifierProvider<ReduceTransparency, bool>(
  ReduceTransparency.new,
);

class ReduceTransparency extends Notifier<bool> {
  @override
  bool build() => ref.read(localFlagsProvider).reduceTransparency;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(localFlagsProvider).setReduceTransparency(value);
  }
}

/// Barra aprovada no Pen.dev em 04/11/2026: Início · Tarefas · Planos ·
/// Agenda ("Calendário" só mudou no texto; a rota é `/calendar`). O Perfil
/// saiu da barra e virou o avatar do topo.
const nexoDestinations = [
  NexoNavigationDestination(icon: LucideIcons.house, label: 'Início'),
  NexoNavigationDestination(icon: LucideIcons.listTodo, label: 'Tarefas'),
  NexoNavigationDestination(icon: LucideIcons.target, label: 'Planos'),
  NexoNavigationDestination(icon: LucideIcons.calendarDays, label: 'Agenda'),
];

/// Casca das 4 abas: o topo (nome da aba, sino e avatar) em cima; o conteúdo
/// passa por trás da barra flutuante de vidro; o "+" fica no mesmo lugar em
/// todas as abas.
class NexoShell extends ConsumerStatefulWidget {
  const NexoShell({
    super.key,
    required this.navigationShell,
    this.showTabHeader = true,
  });

  final StatefulNavigationShell navigationShell;

  /// `false` em telas de detalhe dentro de uma aba (ex.: disciplina), que
  /// têm a própria TopAppBar; a barra de baixo continua.
  final bool showTabHeader;

  @override
  ConsumerState<NexoShell> createState() => _NexoShellState();
}

class _NexoShellState extends ConsumerState<NexoShell> {
  final _bellKey = GlobalKey();

  /// Altura medida do topo das abas (cresce com a fonte ampliada).
  double? _headerHeight;
  final _fabKey = GlobalKey();

  /// Por aba: há conteúdo passando por baixo da barra (vidro adaptativo)?
  /// Guardado por aba porque o `indexedStack` mantém as outras montadas.
  final _overContent = <int, bool>{};

  StatefulNavigationShell get _shell => widget.navigationShell;

  /// Toques na notificação fixa do Foco (com o app aberto).
  StreamSubscription<void>? _focusTaps;

  /// Toques nos avisos agendados (com o app aberto).
  StreamSubscription<String>? _noticeTaps;

  /// Relê a permissão de notificações ao voltar ao app.
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    final system = ref.read(focusSystemProvider);
    _focusTaps = system.openFocusRequests.listen((_) => _openFocus());
    // O app abriu pelo toque na notificação: depois do Login (se preciso),
    // as abas abrem o foco.
    if (system.takeLaunchFromNotification()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openFocus());
    }
    final notices = ref.read(localNoticesProvider);
    _noticeTaps = notices.taps.listen(_openNotice);
    // Entrada no app (também em contas de antes dos avisos): pede a
    // permissão de notificações. O Android só mostra o pedido enquanto a
    // pessoa não decidiu.
    unawaited(ref.read(notificationsAllowedProvider.notifier).request());
    // Voltando ao app (ex.: das configurações), relê a permissão. Voltando
    // do segundo plano, pede de novo se ainda faltar. O `onRestart` só vem
    // de uma volta real: a janela do próprio pedido não passa por ele.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        final allowed = ref.read(notificationsAllowedProvider.notifier);
        if (!allowed.requesting) unawaited(allowed.refresh());
      },
      onRestart: () {
        final allowed = ref.read(notificationsAllowedProvider.notifier);
        final granted = ref.read(notificationsAllowedProvider).value ?? false;
        if (!granted && !allowed.requesting) unawaited(allowed.request());
      },
    );
    // Mesmo caminho para um aviso: depois do Login, as abas levam ao
    // destino.
    final launch = notices.takeLaunchPayload();
    if (launch != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openNotice(launch));
    }
  }

  @override
  void dispose() {
    _focusTaps?.cancel();
    _noticeTaps?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  /// Leva ao destino do aviso (foco-especificacao.md, notificações do
  /// celular): o Início, o detalhe do plano ou o da tarefa. Item que não
  /// existe mais: o Início com "Isso não está mais no Nexo.".
  Future<void> _openNotice(String payload) async {
    if (!mounted) return;
    final router = GoRouter.of(context);
    final (kind, id) = switch (payload.split(':')) {
      [final kind, final id] => (kind, id),
      _ => (payload, ''),
    };
    final String? location = switch (kind) {
      'plan' =>
        (await ref.read(plansProvider.future)).any((p) => p.id == id)
            ? AppRoutes.planDetailOf(id)
            : null,
      'task' =>
        (await ref.read(tasksProvider.future)).any((t) => t.id == id)
            ? AppRoutes.taskDetailOf(id)
            : null,
      _ => AppRoutes.home,
    };
    if (!mounted) return;
    if (location == null) {
      router.go(AppRoutes.home);
      showNexoSnackbar(context, message: 'Isso não está mais no Nexo.');
    } else if (location == AppRoutes.home) {
      router.go(AppRoutes.home);
    } else {
      router.push(location);
    }
  }

  /// Abre o foco em andamento (tela 01, ou 04 se pausado), se ainda houver
  /// um e ele não estiver aberto.
  void _openFocus() {
    if (!mounted || ref.read(activeFocusProvider) == null) return;
    final router = GoRouter.of(context);
    if (router.state.uri.path == AppRoutes.focus) return;
    router.push(AppRoutes.focus);
  }

  /// Lista principal da aba (vertical, não aninhada) com conteúdo além da
  /// borda de baixo: esse conteúdo está sob a cápsula.
  ///
  /// Só conta a aba visível: o `indexedStack` do go_router deixa as outras
  /// em `Offstage` com `TickerMode` desligado, e elas também avisam quando o
  /// layout muda (teclado, rotação).
  bool _onScroll(ScrollMetrics metrics, int depth, BuildContext? source) {
    if (depth != 0 || metrics.axis != Axis.vertical) return false;
    if (source != null && !TickerMode.valuesOf(source).enabled) return false;
    final over = metrics.extentAfter > 0;
    final index = _shell.currentIndex;
    if ((_overContent[index] ?? false) != over) {
      setState(() => _overContent[index] = over);
    }
    return false;
  }

  Rect _rectOf(GlobalKey key) {
    final box = key.currentContext!.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _openNotifications() {
    showNexoNotificationPanel(
      context,
      anchor: _rectOf(_bellKey),
      builder: (panelContext, width, arrowCenter) => NotificationsPanel(
        width: width,
        arrowCenter: arrowCenter,
        onClose: () => Navigator.of(panelContext).pop(),
        onOpen: (item) {
          Navigator.of(panelContext).pop();
          unawaited(_openHistoryItem(item));
        },
      ),
    );
  }

  /// Aviso do sino: leva ao detalhe da tarefa ou do plano, como os avisos
  /// do celular (item apagado: o Início com "Isso não está mais no Nexo."),
  /// e a medalha ao Perfil.
  Future<void> _openHistoryItem(NexoNotification item) async {
    final taskId = item.taskId;
    final planId = item.planId;
    if (taskId != null) return _openNotice(NoticeTarget.task(taskId));
    if (planId != null) return _openNotice(NoticeTarget.plan(planId));
    if (item.kind == NotificationKind.achievement) {
      await context.push(AppRoutes.profile);
      return;
    }
    _openTarget(item.target);
  }

  /// Aviso sem item ligado: a aba correspondente.
  void _openTarget(NotificationTarget target) {
    switch (target) {
      case NotificationTarget.tasks:
        _shell.goBranch(1);
      case NotificationTarget.plans:
        _shell.goBranch(2);
      case NotificationTarget.calendar:
        _shell.goBranch(3);
      case NotificationTarget.profile:
        context.push(AppRoutes.profile);
    }
  }

  void _openCreateMenu() {
    // Criar fica no "+" da barra (decisão travada): Nova tarefa e Novo
    // plano abrem em tela cheia.
    showNexoFabMenu(
      context,
      fabRect: _rectOf(_fabKey),
      options: [
        NexoFabMenuOption(
          icon: LucideIcons.listTodo,
          label: 'Nova tarefa',
          onSelected: () => context.push(AppRoutes.newTask),
        ),
        NexoFabMenuOption(
          icon: LucideIcons.target,
          label: 'Novo plano',
          onSelected: () => context.push(AppRoutes.newPlan),
        ),
      ],
    );
  }

  /// Voltar do aparelho na tela raiz de uma aba (pedido do usuário,
  /// 06/11/2026): fora do Início, vai para o Início; no Início, pergunta se
  /// quer sair. Telas abertas dentro de uma aba (ex.: disciplina) voltam
  /// antes, pelo navegador da aba, sem chegar aqui.
  Future<void> _onBack(bool didPop, Object? _) async {
    if (didPop) return;
    if (_shell.currentIndex != 0) {
      _shell.goBranch(0);
      return;
    }
    final exit = await showNexoDialog(
      context,
      icon: LucideIcons.logOut,
      title: 'Deseja sair do app?',
      message:
          'Você pode voltar quando quiser: suas tarefas e planos ficam '
          'salvos.',
      confirmLabel: 'Sair',
    );
    if (exit) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final solid =
        MediaQuery.highContrastOf(context) ||
        ref.watch(reduceTransparencyProvider);
    final name = ref.watch(userProfileProvider).value?.displayName ?? '';
    // Medalhas: grava as que forem atingidas enquanto o app está aberto
    // (sem Cloud Functions; contrato §4).
    ref.listen(achievementsKeeperProvider, (_, _) {});

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: Scaffold(
        // O conteúdo rola por trás do vidro. O Scaffold soma a altura da barra
        // ao padding de baixo, e a Snackbar flutuante aparece acima dela.
        extendBody: true,
        // O topo das abas fica parado, atrás das abas: as telas raiz começam
        // abaixo dele (NexoTabRoot) e os detalhes, opacos, entram por cima e
        // o cobrem. Antes ele sumia e voltava no meio da transição do
        // detalhe, e a tela saltava 64 px (bug relatado em 08/11/2026).
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizeReporter(
                onHeight: (h) {
                  if (mounted && h != _headerHeight) {
                    setState(() => _headerHeight = h);
                  }
                },
                // Coberto por um detalhe: fora do leitor de tela e do toque.
                child: ExcludeSemantics(
                  excluding: !widget.showTabHeader,
                  child: IgnorePointer(
                    ignoring: !widget.showTabHeader,
                    child: NexoTabHeader(
                      title: nexoDestinations[_shell.currentIndex].label,
                      unreadCount: ref.watch(unreadNotificationsProvider),
                      onNotifications: _openNotifications,
                      bellKey: _bellKey,
                      initials: initialsOf(name),
                      onProfile: () => context.push(AppRoutes.profile),
                      // Saudação só no Início (adendo do pacote B,
                      // 05/11/2026).
                      greeting: _shell.currentIndex == 0
                          ? greetingOf(name)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (n) => _onScroll(n.metrics, n.depth, n.context),
                child: NotificationListener<ScrollUpdateNotification>(
                  onNotification: (n) =>
                      _onScroll(n.metrics, n.depth, n.context),
                  // As telas leem o padding de dentro do Scaffold, em que o
                  // de baixo já inclui a altura da barra (extendBody).
                  child: Builder(
                    builder: (context) {
                      final inset =
                          _headerHeight ??
                          NexoTabHeader.height +
                              MediaQuery.paddingOf(context).top;
                      // Com o topo à mostra, o toque nele (sino, avatar)
                      // atravessa as abas.
                      return TopPassThrough(
                        height: inset,
                        enabled: widget.showTabHeader,
                        child: NexoTabHeaderInset(height: inset, child: _shell),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        // Com um foco em andamento, a Barra do foco fica acima da barra de
        // abas; o Scaffold soma as duas ao padding de baixo, e a Snackbar
        // aparece acima delas.
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ShellFocusBar(),
            NexoBottomBar(
              destinations: nexoDestinations,
              selectedIndex: _shell.currentIndex,
              solid: solid,
              overContent: _overContent[_shell.currentIndex] ?? false,
              fabKey: _fabKey,
              onCreate: _openCreateMenu,
              onSelected: (index) => _shell.goBranch(
                index,
                // Tocar de novo na aba atual volta ao início dela.
                initialLocation: index == _shell.currentIndex,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
