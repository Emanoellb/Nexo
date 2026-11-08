import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/ui/ui.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/notifications/application/notifications_providers.dart';
import '../../features/notifications/domain/nexo_notification.dart';
import '../../features/notifications/presentation/notifications_panel.dart';
import '../router/routes.dart';

/// "Reduzir transparência": troca o vidro da barra pela versão sólida.
/// O Android não expõe essa preferência ao Flutter [NC], então ela será um
/// ajuste do app (tela de Perfil, em bloco futuro). Começa desligada.
final reduceTransparencyProvider = NotifierProvider<ReduceTransparency, bool>(
  ReduceTransparency.new,
);

class ReduceTransparency extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
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
  final _fabKey = GlobalKey();

  /// Por aba: há conteúdo passando por baixo da barra (vidro adaptativo)?
  /// Guardado por aba porque o `indexedStack` mantém as outras montadas.
  final _overContent = <int, bool>{};

  StatefulNavigationShell get _shell => widget.navigationShell;

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
          _openTarget(item.target);
        },
      ),
    );
  }

  /// Na prototipação, o aviso leva à aba correspondente (decisão do usuário,
  /// 04/11/2026); as telas de detalhe ainda não existem.
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: Scaffold(
        // O conteúdo rola por trás do vidro. O Scaffold soma a altura da barra
        // ao padding de baixo, e a Snackbar flutuante aparece acima dela.
        extendBody: true,
        body: Column(
          children: [
            if (widget.showTabHeader)
              NexoTabHeader(
                title: nexoDestinations[_shell.currentIndex].label,
                unreadCount: ref.watch(unreadNotificationsProvider),
                onNotifications: _openNotifications,
                bellKey: _bellKey,
                initials: initialsOf(name),
                onProfile: () => context.push(AppRoutes.profile),
                // Saudação só no Início (adendo do pacote B, 05/11/2026).
                greeting: _shell.currentIndex == 0 ? greetingOf(name) : null,
              ),
            // O topo já respeita a barra de status.
            Expanded(
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (n) => _onScroll(n.metrics, n.depth, n.context),
                child: NotificationListener<ScrollUpdateNotification>(
                  onNotification: (n) =>
                      _onScroll(n.metrics, n.depth, n.context),
                  // O contexto de dentro do Scaffold: é nele que o padding de
                  // baixo já inclui a altura da barra (extendBody). Com o de
                  // fora, as listas ficavam com 0 embaixo e o fim delas ia
                  // para trás da barra (ex.: cartão "Plano" no detalhe).
                  child: Builder(
                    builder: (bodyContext) => MediaQuery.removePadding(
                      context: bodyContext,
                      removeTop: widget.showTabHeader,
                      child: _shell,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: NexoBottomBar(
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
      ),
    );
  }
}
