import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/ui.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/domain/entry_status.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/google_first_access_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/sign_up_page.dart';
import '../../features/auth/presentation/verify_email_page.dart';
import '../../features/calendar/presentation/agenda_page.dart';
import '../../features/focus/presentation/focus_page.dart';
import '../../features/focus/presentation/session_form_page.dart';
import '../../features/focus/presentation/shell_focus_bar.dart';
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
import '../shell/fade_through_branches.dart';
import '../shell/nexo_shell.dart';
import '../shell/tab_root.dart';
import '../shell/under_construction_page.dart';
import 'entry_redirect.dart';
import 'nexo_transitions.dart';
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
        pageBuilder: (context, state) => _page(
          context,
          state,
          LoginPage(initialEmail: state.extra as String?),
          NexoPageMotion.fadeLong,
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
        // Auth (Cadastro, Esqueci a senha, 03b, Verificar) e documentos
        // legais: eixo X, "para dentro" a partir do Login.
        GoRoute(
          path: path,
          pageBuilder: (context, state) =>
              _page(context, state, page(state), NexoPageMotion.sharedAxisX),
        ),
      GoRoute(
        path: AppRoutes.welcome,
        pageBuilder: (context, state) => _page(
          context,
          state,
          const TutorialPage(),
          NexoPageMotion.fadeLong,
        ),
      ),
      StatefulShellRoute(
        // Saída da splash com sessão: esmaece até o Início.
        pageBuilder: (context, state, navigationShell) => _page(
          context,
          state,
          NexoShell(
            navigationShell: navigationShell,
            // Os detalhes dentro das abas têm a própria barra de topo.
            showTabHeader: !AppRoutes.isTabDetail(state.uri.path),
          ),
          NexoPageMotion.fade,
        ),
        // Troca de aba em fade through, mantendo o estado de cada aba.
        navigatorContainerBuilder: (context, navigationShell, children) =>
            FadeThroughBranches(
              currentIndex: navigationShell.currentIndex,
              children: children,
            ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (context, state) => _page(
                  context,
                  state,
                  const NexoTabRoot(child: HomePage()),
                  NexoPageMotion.none,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tasks,
                pageBuilder: (context, state) => _page(
                  context,
                  state,
                  const NexoTabRoot(child: TasksPage()),
                  NexoPageMotion.none,
                ),
                routes: [
                  GoRoute(
                    path: AppRoutes.subjectDetailSegment,
                    pageBuilder: (context, state) => _page(
                      context,
                      state,
                      SubjectDetailPage(subjectId: state.pathParameters['id']!),
                      NexoPageMotion.sharedAxisX,
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
                pageBuilder: (context, state) => _page(
                  context,
                  state,
                  const NexoTabRoot(child: PlansPage()),
                  NexoPageMotion.none,
                ),
                routes: [
                  GoRoute(
                    path: AppRoutes.planDetailSegment,
                    pageBuilder: (context, state) => _page(
                      context,
                      state,
                      PlanDetailPage(planId: state.pathParameters['id']!),
                      NexoPageMotion.sharedAxisX,
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.goalDetailSegment,
                    pageBuilder: (context, state) => _page(
                      context,
                      state,
                      GoalDetailPage(goalId: state.pathParameters['id']!),
                      NexoPageMotion.sharedAxisX,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Agenda ("Calendário" virou "Agenda" só no texto, 04/11/2026; a
          // rota continua `/calendar`).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.calendar,
                pageBuilder: (context, state) => _page(
                  context,
                  state,
                  const NexoTabRoot(child: AgendaPage()),
                  NexoPageMotion.none,
                ),
              ),
            ],
          ),
        ],
      ),
      // Nova tarefa (pelo "+" e pelos vazios) e detalhe da tarefa (pelo
      // toque na tarefa), em tela cheia por cima das abas.
      GoRoute(
        path: AppRoutes.newTask,
        pageBuilder: (context, state) => _page(
          context,
          state,
          const TaskFormPage.create(),
          NexoPageMotion.slideUp,
        ),
      ),
      GoRoute(
        path: AppRoutes.taskDetail,
        pageBuilder: (context, state) => _page(
          context,
          state,
          TaskFormPage.detail(taskId: state.pathParameters['id']!),
          NexoPageMotion.sharedAxisX,
        ),
      ),
      // Criar plano (3 passos) e Editar plano, em tela cheia.
      GoRoute(
        path: AppRoutes.newPlan,
        pageBuilder: (context, state) => _page(
          context,
          state,
          CreatePlanPage(
            makePrimary: state.uri.queryParameters['primary'] == '1',
          ),
          NexoPageMotion.slideUp,
        ),
      ),
      GoRoute(
        path: AppRoutes.editPlan,
        pageBuilder: (context, state) => _page(
          context,
          state,
          EditPlanPage(planId: state.pathParameters['id']!),
          NexoPageMotion.slideUp,
        ),
      ),
      // Foco (sobe ao entrar; minimizar e o voltar descem e mostram a Barra
      // do foco). Registrar horas e Editar sessão: editar (subir).
      GoRoute(
        path: AppRoutes.focus,
        pageBuilder: (context, state) => NexoTransitionPage<void>.of(
          context,
          state,
          const FocusPage(),
          NexoPageMotion.focus,
          morphTarget: focusBarKey,
        ),
      ),
      GoRoute(
        path: AppRoutes.logHours,
        pageBuilder: (context, state) => _page(
          context,
          state,
          SessionFormPage.create(planId: state.uri.queryParameters['plan']),
          NexoPageMotion.slideUp,
        ),
      ),
      GoRoute(
        path: AppRoutes.editSession,
        pageBuilder: (context, state) => _page(
          context,
          state,
          SessionFormPage.edit(
            planId: state.pathParameters['planId']!,
            sessionId: state.pathParameters['sessionId']!,
          ),
          NexoPageMotion.slideUp,
        ),
      ),
      // Perfil: ainda sem design (bloco 11), abre por cima das abas (eixo X).
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) => _page(
          context,
          state,
          Scaffold(
            appBar: NexoTopAppBar(title: 'Perfil', onBack: () => context.pop()),
            body: const UnderConstructionPage(
              title: 'Perfil',
              block: 'bloco 11 · Perfil',
            ),
          ),
          NexoPageMotion.sharedAxisX,
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

/// Página com o padrão de transições (ver [NexoPageMotion]).
Page<void> _page(
  BuildContext context,
  GoRouterState state,
  Widget child,
  NexoPageMotion motion,
) => NexoTransitionPage<void>.of(context, state, child, motion);
