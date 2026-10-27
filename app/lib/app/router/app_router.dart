import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/nexo_theme.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/domain/entry_status.dart';
import '../../features/splash/application/splash_providers.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../shell/nexo_shell.dart';
import '../shell/under_construction_page.dart';
import 'entry_redirect.dart';
import 'routes.dart';

/// Roteador do app. Reavalia o redirecionamento sempre que o status de
/// entrada muda (login, verificação, perfil, tutorial) ou a splash termina.
final routerProvider = Provider<GoRouter>((ref) {
  final gate = ValueNotifier<(EntryStatus, bool)>((
    ref.read(entryStatusProvider),
    ref.read(splashFinishedProvider),
  ));
  ref.listen(
    entryStatusProvider,
    (_, next) => gate.value = (next, gate.value.$2),
  );
  ref.listen(
    splashFinishedProvider,
    (_, next) => gate.value = (gate.value.$1, next),
  );

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: gate,
    redirect: (context, state) => entryRedirect(
      gate.value.$1,
      state.matchedLocation,
      splashFinished: gate.value.$2,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
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
          // Saída da splash sem sessão: o símbolo "voa" até a logo do Login
          // (Hero `nexoLogoHeroTag`, quando a tela real de Login existir).
          pageBuilder: (context, state) => _fadePage(
            context,
            state,
            UnderConstructionPage(
              title: title,
              block: 'bloco 12 · fluxo de entrada',
            ),
            long: true,
          ),
        ),
      StatefulShellRoute.indexedStack(
        // Saída da splash com sessão: esmaece até o Início.
        pageBuilder: (context, state, navigationShell) => _fadePage(
          context,
          state,
          NexoShell(navigationShell: navigationShell),
        ),
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
    gate.dispose();
  });
  return router;
});

/// Transição em esmaecimento com os tokens de movimento: `Medium` (250 ms)
/// ou, com [long], `Long` (350 ms, tempo do Hero da logo). Sem movimento com
/// "reduzir movimento".
Page<void> _fadePage(
  BuildContext context,
  GoRouterState state,
  Widget child, {
  bool long = false,
}) {
  final motion = context.motion;
  final duration = MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : (long ? motion.long : motion.medium);
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: motion.standard),
          child: child,
        ),
  );
}
