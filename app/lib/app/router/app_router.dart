import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/nexo_theme.dart';
import '../../core/ui/ui.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/domain/entry_status.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/google_first_access_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/sign_up_page.dart';
import '../../features/auth/presentation/verify_email_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/legal/presentation/legal_document_page.dart';
import '../../features/tutorial/presentation/tutorial_page.dart';
import '../../features/splash/application/splash_providers.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../../features/subjects/presentation/subject_detail_page.dart';
import '../../features/goals/presentation/goal_detail_page.dart';
import '../../features/plans/presentation/create_plan_page.dart';
import '../../features/plans/presentation/edit_plan_page.dart';
import '../../features/plans/presentation/plan_detail_page.dart';
import '../../features/plans/presentation/plans_page.dart';
import '../../features/tasks/presentation/task_form_page.dart';
import '../../features/tasks/presentation/tasks_page.dart';
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
      GoRoute(
        path: AppRoutes.login,
        // Saída da splash sem sessão: o símbolo "voa" até a logo do Login
        // (Hero `nexoLogoHeroTag`).
        pageBuilder: (context, state) => _fadePage(
          context,
          state,
          LoginPage(initialEmail: state.extra as String?),
          long: true,
        ),
      ),
      for (final (path, page) in [
        (
          AppRoutes.forgotPassword,
          (GoRouterState state) =>
              ForgotPasswordPage(initialEmail: state.extra as String?),
        ),
        (AppRoutes.signUp, (GoRouterState _) => const SignUpPage()),
        (
          AppRoutes.googleFirstAccess,
          (GoRouterState _) => const GoogleFirstAccessPage(),
        ),
        (AppRoutes.verifyEmail, (GoRouterState _) => const VerifyEmailPage()),
        (
          AppRoutes.terms,
          (GoRouterState _) =>
              const LegalDocumentPage(document: LegalDocument.terms),
        ),
        (
          AppRoutes.privacy,
          (GoRouterState _) =>
              const LegalDocumentPage(document: LegalDocument.privacy),
        ),
      ])
        GoRoute(
          path: path,
          pageBuilder: (context, state) =>
              _fadePage(context, state, page(state)),
        ),
      GoRoute(
        path: AppRoutes.welcome,
        pageBuilder: (context, state) =>
            _fadePage(context, state, const TutorialPage(), long: true),
      ),
      StatefulShellRoute.indexedStack(
        // Saída da splash com sessão: esmaece até o Início.
        pageBuilder: (context, state, navigationShell) => _fadePage(
          context,
          state,
          NexoShell(
            navigationShell: navigationShell,
            // Os detalhes dentro das abas têm a própria barra de topo.
            showTabHeader: !AppRoutes.isTabDetail(state.uri.path),
          ),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tasks,
                builder: (context, state) => const TasksPage(),
                routes: [
                  GoRoute(
                    path: AppRoutes.subjectDetailSegment,
                    builder: (context, state) => SubjectDetailPage(
                      subjectId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.plans,
                builder: (context, state) => const PlansPage(),
                routes: [
                  GoRoute(
                    path: AppRoutes.planDetailSegment,
                    builder: (context, state) =>
                        PlanDetailPage(planId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: AppRoutes.goalDetailSegment,
                    builder: (context, state) =>
                        GoalDetailPage(goalId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          for (final (path, title, block) in const [
            // "Calendário" virou "Agenda" só no texto (04/11/2026).
            (AppRoutes.calendar, 'Agenda', 'bloco 9 · Calendário'),
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
      // Nova tarefa (pelo "+" e pelos vazios) e detalhe da tarefa (pelo
      // toque na tarefa), em tela cheia por cima das abas.
      GoRoute(
        path: AppRoutes.newTask,
        pageBuilder: (context, state) =>
            _fadePage(context, state, const TaskFormPage.create()),
      ),
      GoRoute(
        path: AppRoutes.taskDetail,
        pageBuilder: (context, state) => _fadePage(
          context,
          state,
          TaskFormPage.detail(taskId: state.pathParameters['id']!),
        ),
      ),
      // Criar plano (3 passos) e Editar plano, em tela cheia.
      GoRoute(
        path: AppRoutes.newPlan,
        pageBuilder: (context, state) => _fadePage(
          context,
          state,
          CreatePlanPage(
            makePrimary: state.uri.queryParameters['primary'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.editPlan,
        pageBuilder: (context, state) => _fadePage(
          context,
          state,
          EditPlanPage(planId: state.pathParameters['id']!),
        ),
      ),
      // Telas por cima das abas ainda sem design ou de áreas futuras.
      for (final (path, title, block) in const [
        (AppRoutes.profile, 'Perfil', 'bloco 11 · Perfil'),
        // Destinos provisórios da aba Sessões: entram na feat/foco.
        (AppRoutes.logHours, 'Registrar horas', 'Foco'),
        (AppRoutes.editSession, 'Editar sessão', 'Foco'),
      ])
        GoRoute(
          path: path,
          // Por cima das abas, com voltar (Perfil pelo avatar do topo).
          pageBuilder: (context, state) => _fadePage(
            context,
            state,
            Scaffold(
              appBar: NexoTopAppBar(title: title, onBack: () => context.pop()),
              body: UnderConstructionPage(title: title, block: block),
            ),
          ),
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
