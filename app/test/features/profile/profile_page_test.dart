import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
  Future<bool> openEmail(
    String address, {
    String? subject,
    String? body,
  }) async {
    calls.add('email:$address');
    emails.add((address: address, subject: subject, body: body));
    return opens;
  }

  final emails = <({String address, String? subject, String? body})>[];

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
  AuthUser? user,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final auth = user == null
      ? FakeAuthRepository.signedIn()
      : FakeAuthRepository(initialUser: user, withPrototypeAccounts: true);
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
    // Escondido até o agendamento existir (Etapa 5).
    expect(find.text('Aviso da manhã'), findsNothing);
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
    await tester.scrollUntilVisible(
      find.text('Sobre o Nexo · versão 1.0.0'),
      200,
    );
    expect(find.text(NexoSupport.email), findsOneWidget);
    // Telefone fictício escondido até haver o número real.
    expect(find.text('Telefone'), findsNothing);
    expect(find.text(NexoSupport.phoneText), findsNothing);
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

  testWidgets('preferências: tema, transparência e limite', (tester) async {
    final ctx = await _pump(tester);
    await _tap(tester, find.text('Escuro'));
    expect(ctx.flags.themePreference, 'dark');

    await _tap(tester, find.text('Reduzir transparência'));
    expect(ctx.c.read(reduceTransparencyProvider), isTrue);
    expect(ctx.flags.reduceTransparency, isTrue);

    await _tap(tester, find.byTooltip('Aumentar o limite'));
    expect(find.text('6 tarefas'), findsOneWidget);
    expect(_profile(ctx.c).overloadThreshold, 6);
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

  testWidgets('suporte abre o e-mail; sem app, avisa', (tester) async {
    final ctx = await _pump(tester, deviceOpens: false);
    await _tap(tester, find.text('E-mail'));
    expect(ctx.device.calls, ['email:${NexoSupport.email}']);
    expect(
      find.textContaining('Nenhum app de e-mail encontrado'),
      findsOneWidget,
    );
  });

  testWidgets('bloco Conta: ordem, chevron nos documentos e Pedir cópia', (
    tester,
  ) async {
    final ctx = await _pump(tester);
    final rows = tester
        .widgetList<NexoListItem>(
          find.descendant(
            of: find.ancestor(
              of: find.text('Termos de uso'),
              matching: find.byType(NexoCardList),
            ),
            matching: find.byType(NexoListItem),
          ),
        )
        .map((r) => r.title)
        .toList();
    expect(rows, [
      'Termos de uso',
      'Política de privacidade',
      'Pedir cópia dos dados',
      'Alterar senha',
      'Sair',
      'Excluir conta',
    ]);
    // Termos e Política abrem no app: chevron, não link externo.
    for (final title in ['Termos de uso', 'Política de privacidade']) {
      final row = find.widgetWithText(NexoListItem, title);
      expect(
        find.descendant(
          of: row,
          matching: find.byIcon(LucideIcons.chevronRight),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.byIcon(LucideIcons.externalLink),
        ),
        findsNothing,
      );
    }

    // Suporte com o assunto.
    await _tap(tester, find.text('E-mail'));
    expect(ctx.device.emails.last.subject, 'Nexo · suporte');

    // Pedir cópia: a mensagem pronta, sem o e-mail da conta.
    await _tap(tester, find.text('Pedir cópia dos dados'));
    final mail = ctx.device.emails.last;
    expect(mail.address, NexoSupport.email);
    expect(mail.subject, 'Nexo · cópia dos meus dados');
    expect(mail.body, 'Olá! Quero receber uma cópia dos meus dados do Nexo.');
    expect(mail.body, isNot(contains(FakeAuthRepository.prototypeEmail)));
  });

  testWidgets('Pedir cópia sem app de e-mail: Snackbar com o endereço e o '
      'assunto', (tester) async {
    await _pump(tester, deviceOpens: false);
    await _tap(tester, find.text('Pedir cópia dos dados'));
    expect(
      find.text(
        'Nenhum app de e-mail encontrado. Escreva para ${NexoSupport.email} '
        'com o assunto “Nexo · cópia dos meus dados”.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Alterar senha envia o link direto, sem confirmação', (
    tester,
  ) async {
    await _pump(tester);
    await _tap(tester, find.text('Alterar senha'));
    expect(
      find.text('Enviamos um link para ${FakeAuthRepository.prototypeEmail}.'),
      findsOneWidget,
    );
  });

  for (final (local, message) in const [
    ('sem-conexao', 'Sem conexão com a internet. Verifique e tente de novo.'),
    ('muitas-tentativas', 'Muitas tentativas. Tente de novo mais tarde.'),
    ('erro', 'Não conseguimos enviar o link agora. Tente de novo.'),
  ]) {
    testWidgets('Alterar senha · erro "$local"', (tester) async {
      await _pump(
        tester,
        user: AuthUser(
          uid: _uid,
          emailVerified: true,
          email: '$local@exemplo.com',
        ),
      );
      await _tap(tester, find.text('Alterar senha'));
      expect(find.text(message), findsOneWidget);
    });
  }

  testWidgets('conta Google não tem "Alterar senha"', (tester) async {
    await _pump(
      tester,
      user: const AuthUser(
        uid: _uid,
        emailVerified: true,
        signedInWithGoogle: true,
        email: FakeAuthRepository.googleEmail,
      ),
    );
    expect(find.text('Alterar senha'), findsNothing);
    expect(find.text('Pedir cópia dos dados'), findsOneWidget);
  });

  testWidgets('"Sobre o Nexo": nome, versão, quem oferece e as licenças', (
    tester,
  ) async {
    await _pump(tester);
    final about = find.text('Sobre o Nexo · versão 1.0.0');
    expect(about, findsOneWidget);
    expect(find.bySemanticsLabel('Sobre o Nexo, versão 1.0.0'), findsOneWidget);
    await _tap(tester, about);
    expect(find.text('Sobre o Nexo'), findsOneWidget);
    expect(find.text('Nexo'), findsWidgets);
    expect(find.text('Versão 1.0.0'), findsOneWidget);
    expect(find.text('Oferecido por Emanoel Lima Barbosa'), findsOneWidget);
    expect(find.byType(LicensePage), findsNothing);
    await _tap(tester, _button('Ver licenças e componentes'));
    expect(find.byType(LicensePage), findsOneWidget);
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
    // O que o aparelho guarda da conta (e um ajuste do aparelho).
    await ctx.flags.setDndOnFocus(_uid, true);
    await ctx.flags.setDndAllowed(_uid);
    await ctx.flags.markFirstStepsDone(_uid);
    await ctx.flags.setActiveFocus(_uid, '{}');
    await ctx.flags.setReduceTransparency(true);
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
    // O aparelho esquece a conta; o que é do aparelho fica.
    expect(ctx.flags.dndOnFocus(_uid), isFalse);
    expect(ctx.flags.dndAllowed(_uid), isFalse);
    expect(ctx.flags.firstStepsDone(_uid), isFalse);
    expect(ctx.flags.activeFocus(_uid), isNull);
    expect(ctx.flags.reduceTransparency, isTrue);
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
