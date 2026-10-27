import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/ui/ui.dart';

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

/// Ordem decidida em 26/10/2026: Início · Tarefas · Planos · Calendário ·
/// Perfil. Ícones provisórios, a conferir com o `nexo.lib.pen` em 28/10.
const nexoDestinations = [
  NexoNavigationDestination(icon: LucideIcons.house, label: 'Início'),
  NexoNavigationDestination(icon: LucideIcons.listTodo, label: 'Tarefas'),
  NexoNavigationDestination(icon: LucideIcons.target, label: 'Planos'),
  NexoNavigationDestination(
    icon: LucideIcons.calendarDays,
    label: 'Calendário',
  ),
  NexoNavigationDestination(icon: LucideIcons.user, label: 'Perfil'),
];

/// Casca das 5 abas: o conteúdo passa por trás da barra flutuante de vidro.
class NexoShell extends ConsumerWidget {
  const NexoShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solid =
        MediaQuery.highContrastOf(context) ||
        ref.watch(reduceTransparencyProvider);
    return Scaffold(
      // O conteúdo rola por trás do vidro. O Scaffold soma a altura da barra
      // ao padding de baixo, e a Snackbar flutuante aparece acima dela.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: NexoNavigationBar(
        destinations: nexoDestinations,
        selectedIndex: navigationShell.currentIndex,
        solid: solid,
        onSelected: (index) => navigationShell.goBranch(
          index,
          // Tocar de novo na aba atual volta ao topo dela.
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
