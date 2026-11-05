import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/ui/ui.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/notifications/application/notifications_providers.dart';
import '../../features/notifications/domain/nexo_notification.dart';
import '../../features/notifications/presentation/notifications_panel.dart';
import '../prototype/prototype_actions.dart';
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
  const NexoShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<NexoShell> createState() => _NexoShellState();
}

class _NexoShellState extends ConsumerState<NexoShell> {
  final _bellKey = GlobalKey();
  final _fabKey = GlobalKey();

  StatefulNavigationShell get _shell => widget.navigationShell;

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
    final actions = ref.read(prototypeActionsProvider);
    // Telas de criar ainda não desenhadas: o toque cria um exemplo nos dados
    // fake (decisão do usuário, 04/11/2026).
    void created(String message) {
      if (mounted) showNexoSnackbar(context, message: message);
    }

    showNexoFabMenu(
      context,
      fabRect: _rectOf(_fabKey),
      options: [
        NexoFabMenuOption(
          icon: LucideIcons.listTodo,
          label: 'Nova tarefa',
          onSelected: () async {
            final task = await actions.createSampleTask();
            created('"${task.title}" criada para hoje.');
          },
        ),
        NexoFabMenuOption(
          icon: LucideIcons.target,
          label: 'Novo plano',
          onSelected: () async {
            final plan = await actions.createSamplePlan();
            created('"${plan.name}" criado.');
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final solid =
        MediaQuery.highContrastOf(context) ||
        ref.watch(reduceTransparencyProvider);
    final name = ref.watch(userProfileProvider).value?.displayName ?? '';

    return Scaffold(
      // O conteúdo rola por trás do vidro. O Scaffold soma a altura da barra
      // ao padding de baixo, e a Snackbar flutuante aparece acima dela.
      extendBody: true,
      body: Column(
        children: [
          NexoTabHeader(
            title: nexoDestinations[_shell.currentIndex].label,
            unreadCount: ref.watch(unreadNotificationsProvider),
            onNotifications: _openNotifications,
            bellKey: _bellKey,
            initials: initialsOf(name),
            onProfile: () => context.push(AppRoutes.profile),
          ),
          // O topo já respeita a barra de status.
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: _shell,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NexoBottomBar(
        destinations: nexoDestinations,
        selectedIndex: _shell.currentIndex,
        solid: solid,
        fabKey: _fabKey,
        onCreate: _openCreateMenu,
        onSelected: (index) => _shell.goBranch(
          index,
          // Tocar de novo na aba atual volta ao início dela.
          initialLocation: index == _shell.currentIndex,
        ),
      ),
    );
  }
}
