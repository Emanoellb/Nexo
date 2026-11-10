import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/app/router/app_router.dart';
import 'package:nexo/app/router/routes.dart';
import 'package:nexo/app/shell/nexo_shell.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/data/device_actions.dart';
import 'package:nexo/core/data/local_flags.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/core/ui/ui.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/data/fake_auth_repository.dart';
import 'package:nexo/features/auth/domain/auth_user.dart';
import 'package:nexo/features/auth/presentation/login_page.dart';
import 'package:nexo/features/plans/application/plans_providers.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';
import 'package:nexo/features/profile/application/profile_actions.dart';
import 'package:nexo/features/profile/presentation/delete_account_pages.dart';
import 'package:nexo/features/profile/presentation/edit_profile_page.dart';
import 'package:nexo/features/profile/presentation/profile_page.dart';
import 'package:nexo/features/progress/domain/achievements.dart';

// Quarta, 04/11/2026, 10:00.
final _now = DateTime(2026, 11, 4, 10);
const _today = LocalDate(2026, 11, 4);
const _uid = FakeAuthRepository.prototypeUserUid;

/// Ações do aparelho falsas: registram o que o Perfil pediu.
class _FakeDevice implements DeviceActions {
  _FakeDevice({this.opens = true});

  final bool opens;
  final calls = <String>[];

  @override
  Future<bool> openEmail(String address) async {
    calls.add('email:$address');
    return opens;
  }

  @override
  Future<bool> openDialer(String number) async {
    calls.add('tel:$number');
    return opens;
  }

  @override
  Future<String?> appVersion() async => '1.0.0';
}

class _Ctx {
  _Ctx(this.c, this.auth, this.profiles, this.flags, this.device);

  final ProviderContainer c;
  final FakeAuthRepository auth;
  final FakeUserProfileRepository profiles;
  final InMemoryLocalFlags flags;
  final _FakeDevice device;
}

/// App logado na conta de protótipo ("Ana", 12/03/2003), já no Perfil.
Future<_Ctx> _pump(
  WidgetTester tester, {
  bool dark = false,
  double textScale = 1,
  bool deviceOpens = true,
  UserProfile? profile,
  bool openProfile = true,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final auth = FakeAuthRepository.signedIn();
  final profiles = FakeUserProfileRepository.prototype()..now = () => _now;
  if (profile != null) profiles.setProfile(_uid, profile);
  final flags = InMemoryLocalFlags(
    firstOpenDone: true,
    themePreference: dark ? 'dark' : 'light',
  );
  final device = _FakeDevice(opens: deviceOpens);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userProfileRepositoryProvider.overrideWithValue(profiles),
        clockProvider.overrideWithValue(() => _now),
        localFlagsProvider.overrideWithValue(flags),
        deviceActionsProvider.overrideWithValue(device),
      ],
      child: const NexoApp(),
    ),
  );
  await tester.pumpAndSettle();
  final c = ProviderScope.containerOf(tester.element(find.byType(NexoApp)));
  if (openProfile) {
    await tester.tap(find.bySemanticsLabel('Perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
  }
  return _Ctx(c, auth, profiles, flags, device);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.widgetWithText(NexoButton, label);

UserProfile _profile(ProviderContainer c) => c.read(userProfileProvider).value!;

void main() {
  test('critérios das medalhas: progresso e quanto falta', () {
    const inputs = AchievementInputs(
      plans: 1,
      focusSessions: 0,
      metDays: 3,
      longestStreak: 5,
      completedTasks: 4,
      finishedPlans: 0,
      daysToFinishPlan: 20,
    );
    final byId = {for (final d in NexoAchievements.catalog) d.id: d};
    expect(NexoAchievements.catalog, hasLength(9));
    expect(NexoAchievements.isMet(byId['primeiro-plano']!, inputs), isTrue);
    expect(NexoAchievements.isMet(byId['primeiro-foco']!, inputs), isFalse);
    expect(NexoAchievements.isMet(byId['sete-dias']!, inputs), isFalse);
    expect(
      NexoAchievements.missingText(byId['sete-dias']!, inputs),
      'Faltam 2 dias seguidos.',
    );
    expect(
      NexoAchievements.missingText(byId['dez-tarefas']!, inputs),
      'Faltam 6 tarefas.',
    );
    expect(
      NexoAchievements.missingText(byId['plano-concluido']!, inputs),
      'Faltam 20 dias para o fim do seu plano.',
    );
  });

  testWidgets('01 Perfil: topo, progresso, medalhas, preferências, suporte e '
      'conta', (tester) async {
    await _pump(tester);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text(FakeAuthRepository.prototypeEmail), findsOneWidget);
    expect(find.text('Editar perfil'), findsOneWidget);
    expect(find.text('Nível 1'), findsOneWidget);
    expect(find.text('0 / 20 pontos'), findsOneWidget);
    expect(find.text('0 de 9'), findsOneWidget);
    expect(find.byType(NexoAchievement), findsNWidgets(9));
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Aviso da manhã'), findsOneWidget);
    expect(find.text('5 tarefas'), findsOneWidget);
    // O rótulo visível acima do ajuste (bug de 10/11/2026: só havia o do
    // leitor de tela).
    expect(find.text('Limite de tarefas por dia'), findsOneWidget);
    expect(
      tester.getRect(find.text('Limite de tarefas por dia')).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('5 tarefas')).top),
    );
    // Sem as partes nativas (testes), o "Não perturbe" não aparece.
    expect(find.text('Ligar o Não perturbe ao focar'), findsNothing);
    await tester.scrollUntilVisible(find.text('Nexo 1.0.0'), 200);
    expect(find.text(NexoSupport.email), findsOneWidget);
    expect(find.text(NexoSupport.phoneText), findsOneWidget);
    expect(find.text('Excluir conta'), findsOneWidget);
  });

  testWidgets('03 e 04 medalhas: conquistada com a data; bloqueada com o que '
      'falta', (tester) async {
    final ctx = await _pump(tester);
    await ctx.c
        .read(plansRepositoryProvider)
        .createPlan(
          Plan(
            id: '',
            name: 'Concurso Banco Horizonte',
            startDate: _today,
            endDate: _today.addDays(30),
            frequency: const DailyFrequency(),
            dailyGoalMinutes: 45,
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('1 de 9'), findsOneWidget);

    await _tap(tester, find.bySemanticsLabel('Primeiro plano, conquistada'));
    expect(find.text('Crie seu primeiro plano de ação.'), findsOneWidget);
    expect(find.text('Conquistada em 4 de novembro de 2026'), findsOneWidget);
    await _tap(tester, _button('Fechar'));

    await _tap(
      tester,
      find.bySemanticsLabel('10 tarefas concluídas, bloqueada'),
    );
    expect(find.text('Conclua 10 tarefas.'), findsOneWidget);
    expect(find.text('Faltam 10 tarefas.'), findsOneWidget);
  });

  testWidgets('preferências: tema, transparência, limite e aviso da manhã', (
    tester,
  ) async {
    final ctx = await _pump(tester);
    await _tap(tester, find.text('Escuro'));
    expect(ctx.flags.themePreference, 'dark');

    await _tap(tester, find.text('Reduzir transparência'));
    expect(ctx.c.read(reduceTransparencyProvider), isTrue);
    expect(ctx.flags.reduceTransparency, isTrue);

    await _tap(tester, find.byTooltip('Aumentar o limite'));
    expect(find.text('6 tarefas'), findsOneWidget);
    expect(_profile(ctx.c).overloadThreshold, 6);

    expect(find.text('Horário'), findsOneWidget);
    await _tap(tester, find.text('Aviso da manhã'));
    expect(_profile(ctx.c).morningSummary.enabled, isFalse);
    expect(find.text('Horário'), findsNothing);
  });

  testWidgets('limite: não passa de 1 nem de 20', (tester) async {
    final ctx = await _pump(
      tester,
      profile: const UserProfile(
        displayName: 'Ana',
        tutorialSeen: true,
        overloadThreshold: 1,
      ),
    );
    final minus = tester.widget<NexoIconButton>(
      find.ancestor(
        of: find.byTooltip('Diminuir o limite'),
        matching: find.byType(NexoIconButton),
      ),
    );
    expect(minus.onPressed, isNull);
    await ctx.c.read(profileActionsProvider).setOverloadThreshold(25);
    await tester.pumpAndSettle();
    expect(_profile(ctx.c).overloadThreshold, 20);
  });

  testWidgets('suporte abre o e-mail e o discador; sem app, avisa', (
    tester,
  ) async {
    final ctx = await _pump(tester, deviceOpens: false);
    await _tap(tester, find.text('E-mail'));
    expect(ctx.device.calls, ['email:${NexoSupport.email}']);
    expect(
      find.textContaining('Nenhum app de e-mail encontrado'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Telefone'));
    expect(ctx.device.calls.last, 'tel:${NexoSupport.phoneDial}');
    expect(
      find.text('Nenhum discador encontrado neste aparelho.'),
      findsOneWidget,
    );
  });

  testWidgets('05 Editar perfil: só o nome; e-mail e nascimento só leitura', (
    tester,
  ) async {
    final ctx = await _pump(tester);
    await _tap(tester, find.text('Editar perfil'));
    expect(find.byType(EditProfilePage), findsOneWidget);
    expect(find.text('12/03/2003'), findsOneWidget);
    expect(find.text('Somente leitura.'), findsOneWidget);
    expect(_button('Salvar'), findsOneWidget);
    expect(tester.widget<NexoButton>(_button('Salvar')).onPressed, isNull);

    await tester.enterText(find.widgetWithText(NexoTextField, 'Nome'), ' ');
    await tester.pump();
    await _tap(tester, _button('Salvar'));
    expect(find.text('Informe seu nome.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(NexoTextField, 'Nome'),
      'Ana Souza',
    );
    await _tap(tester, _button('Salvar'));
    expect(find.text('Alterações salvas.'), findsOneWidget);
    expect(_profile(ctx.c).displayName, 'Ana Souza');
    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('06 Sair pede confirmação e volta ao Login', (tester) async {
    await _pump(tester);
    await _tap(tester, find.text('Sair'));
    expect(find.text('Sair da conta?'), findsOneWidget);
    await _tap(tester, _button('Sair'));
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('07 a 10 Excluir conta: caixa, senha, excluindo e Login', (
    tester,
  ) async {
    final ctx = await _pump(tester);
    await _tap(tester, find.text('Excluir conta'));
    expect(find.byType(DeleteAccountPage), findsOneWidget);
    expect(find.text('Excluir conta?'), findsOneWidget);
    expect(tester.widget<NexoButton>(_button('Continuar')).onPressed, isNull);
    await _tap(
      tester,
      find.text('Desejo excluir minha conta e entendo que isso não tem volta.'),
    );
    await _tap(tester, _button('Continuar'));
    expect(find.byType(ConfirmDeletionPage), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'errada');
    await _tap(tester, _button('Excluir conta'));
    expect(find.text('Senha incorreta.'), findsOneWidget);
    expect(_profile(ctx.c).deletionRequestedAt, isNull);

    await tester.enterText(
      find.byType(TextField),
      FakeAuthRepository.prototypePassword,
    );
    await tester.tap(_button('Excluir conta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Conta excluída.'), findsOneWidget);
    // A conta não existe mais (o login fake espera um instante: o relógio
    // do teste anda com o pump).
    final attempt = ctx.auth
        .signInWithEmail(
          email: FakeAuthRepository.prototypeEmail,
          password: FakeAuthRepository.prototypePassword,
        )
        .then((_) => true, onError: (_) => false);
    await tester.pump(const Duration(seconds: 1));
    expect(await attempt, isFalse);
  });

  testWidgets('exclusão interrompida continua no próximo login', (
    tester,
  ) async {
    await _pump(
      tester,
      openProfile: false,
      profile: UserProfile(
        displayName: 'Ana',
        tutorialSeen: true,
        deletionRequestedAt: _now,
      ),
    );
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Conta excluída.'), findsOneWidget);
  });

  testWidgets('Termos e Política abrem os documentos', (tester) async {
    final ctx = await _pump(tester);
    await _tap(tester, find.text('Termos de uso'));
    expect(ctx.c.read(routerProvider).state.uri.path, AppRoutes.terms);
  });

  for (final dark in [false, true]) {
    testWidgets('fonte 2,0 sem estouro · ${dark ? 'escuro' : 'claro'}', (
      tester,
    ) async {
      final ctx = await _pump(tester, dark: dark, textScale: 2);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Excluir conta'), 300);
      expect(tester.takeException(), isNull);
      ctx.c.read(routerProvider).push(AppRoutes.editProfile);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
