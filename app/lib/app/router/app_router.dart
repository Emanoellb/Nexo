import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/ui.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/domain/entry_status.dart';
import '../shell/nexo_shell.dart';
import '../shell/under_construction_page.dart';
import 'entry_redirect.dart';
import 'routes.dart';

/// Roteador do app. Reavalia o redirecionamento sempre que o status de
/// entrada muda (login, verificação, perfil, tutorial).
final routerProvider = Provider<GoRouter>((ref) {
  final status = ValueNotifier<EntryStatus>(ref.read(entryStatusProvider));
  ref.listen(entryStatusProvider, (_, next) => status.value = next);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: status,
    redirect: (context, state) =>
        entryRedirect(status.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashPlaceholder(),
      ),
      for (final (path, title) in const [
        (AppRoutes.login, 'Entrar'),
        (AppRoutes.forgotPassword, 'Esqueci minha senha'),
        (AppRoutes.signUp, 'Criar conta'),
        (AppRoutes.googleFirstAccess, 'Primeiro acesso'),
        (AppRoutes.verifyEmail, 'Verifique seu e-mail'),
        (AppRoutes.welcome, 'Boas-vindas'),
      ])
        GoRoute(
          path: path,
          builder: (context, state) => UnderConstructionPage(
            title: title,
            block: 'bloco 12 · fluxo de entrada',
          ),
        ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            NexoShell(navigationShell: navigationShell),
        branches: [
          for (final (path, title, block) in const [
            (AppRoutes.home, 'Início', 'bloco 6 · Início'),
            (AppRoutes.tasks, 'Tarefas', 'bloco 7 · Tarefas'),
            (AppRoutes.plans, 'Planos', 'bloco 3 · Planos'),
            (AppRoutes.calendar, 'Calendário', 'bloco 9 · Calendário'),
            (AppRoutes.profile, 'Perfil', 'bloco 11 · Perfil'),
          ])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (context, state) =>
                      UnderConstructionPage(title: title, block: block),
                ),
              ],
            ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    status.dispose();
  });
  return router;
});

/// Splash provisória: símbolo estático enquanto o auth carrega. A animação
/// do "x" entra no bloco 12, depois de você aprovar o roteiro.
class _SplashPlaceholder extends StatelessWidget {
  const _SplashPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: NexoLogoSymbol(size: 96)));
  }
}
