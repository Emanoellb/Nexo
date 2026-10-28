import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/data/local_flags.dart';
import 'package:nexo/core/ui/ui.dart';
import 'package:nexo/features/auth/application/auth_messages.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/data/fake_auth_repository.dart';
import 'package:nexo/features/auth/domain/auth_user.dart';
import 'package:nexo/features/legal/data/legal_documents_repository.dart';

const _home = 'Em construção · bloco 6 · Início';

class _App {
  _App(this.auth, this.profiles);

  final FakeAuthRepository auth;
  final FakeUserProfileRepository profiles;
}

/// O app inteiro com o auth simulado, num celular de 360 × 800.
Future<_App> _pumpApp(WidgetTester tester, {AuthUser? user}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final auth = FakeAuthRepository(
    initialUser: user,
    withPrototypeAccounts: true,
  );
  final profiles = FakeUserProfileRepository.prototype();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userProfileRepositoryProvider.overrideWithValue(profiles),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 27, 12)),
        localFlagsProvider.overrideWithValue(
          InMemoryLocalFlags(firstOpenDone: true),
        ),
      ],
      child: const NexoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return _App(auth, profiles);
}

Finder _field(String label) => find.descendant(
  of: find.widgetWithText(NexoTextField, label),
  matching: find.byType(TextField),
);

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(_field(label));
  await tester.enterText(_field(label), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _blur(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

NexoButton _button(WidgetTester tester, String label) =>
    tester.widget<NexoButton>(find.widgetWithText(NexoButton, label));

void main() {
  group('02 Login', () {
    testWidgets('sem sessão abre no Login; campos vazios mostram os erros', (
      tester,
    ) async {
      await _pumpApp(tester);
      expect(find.text('Entre na sua conta'), findsOneWidget);

      await _tap(tester, find.widgetWithText(NexoButton, 'Entrar'));
      expect(find.text(AuthMessages.emailEmpty), findsOneWidget);
      expect(find.text(AuthMessages.passwordEmptyLogin), findsOneWidget);

      await _type(tester, 'E-mail', 'ana.souza@email');
      await _tap(tester, find.widgetWithText(NexoButton, 'Entrar'));
      expect(find.text(AuthMessages.emailInvalid), findsOneWidget);
    });

    testWidgets('senha errada mostra o alerta; a certa leva ao Início', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _type(tester, 'E-mail', FakeAuthRepository.prototypeEmail);
      await _type(tester, 'Senha', 'Errada#123');
      await _tap(tester, find.widgetWithText(NexoButton, 'Entrar'));
      expect(find.text('E-mail ou senha incorretos'), findsOneWidget);

      // Corrigir a senha tira o alerta.
      await _type(tester, 'Senha', FakeAuthRepository.prototypePassword);
      expect(find.text('E-mail ou senha incorretos'), findsNothing);
      await _tap(tester, find.widgetWithText(NexoButton, 'Entrar'));
      expect(find.text(_home), findsOneWidget);
    });

    testWidgets('sem conexão mantém os dados digitados', (tester) async {
      await _pumpApp(tester);
      await _type(tester, 'E-mail', 'sem-conexao@email.com');
      await _type(tester, 'Senha', 'Qualquer#1');
      await _tap(tester, find.widgetWithText(NexoButton, 'Entrar'));
      expect(find.text('Você está sem conexão'), findsOneWidget);
      expect(find.text('sem-conexao@email.com'), findsOneWidget);

      // Some em 5 s.
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Você está sem conexão'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Você está sem conexão'), findsNothing);
    });

    testWidgets('muitas tentativas desabilita Entrar e leva à redefinição', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _type(tester, 'E-mail', 'muitas-tentativas@email.com');
      await _type(tester, 'Senha', 'Qualquer#1');
      await _tap(tester, find.widgetWithText(NexoButton, 'Entrar'));
      expect(find.text('Muitas tentativas'), findsOneWidget);
      expect(_button(tester, 'Entrar').onPressed, isNull);

      await _tap(tester, find.widgetWithText(NexoButton, 'Redefinir senha'));
      expect(find.text('Redefina sua senha'), findsOneWidget);
      // O e-mail digitado vem junto.
      expect(find.text('muitas-tentativas@email.com'), findsOneWidget);

      // O bloqueio do Login termina em 60 s.
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('"Muitas tentativas" sai quando o bloqueio termina', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _type(tester, 'E-mail', 'muitas-tentativas@email.com');
      await _type(tester, 'Senha', 'Qualquer#1');
      await _tap(tester, find.widgetWithText(NexoButton, 'Entrar'));
      expect(find.text('Muitas tentativas'), findsOneWidget);

      expect(find.textContaining('tentar de novo em 1:00'), findsOneWidget);
      await tester.pump(const Duration(seconds: 15));
      expect(find.textContaining('tentar de novo em 0:45'), findsOneWidget);
      await tester.pump(const Duration(seconds: 44));
      expect(find.text('Muitas tentativas'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Muitas tentativas'), findsNothing);
      expect(_button(tester, 'Entrar').onPressed, isNotNull);
    });
  });

  group('03 Cadastro', () {
    Future<void> openSignUp(WidgetTester tester) async {
      await _tap(tester, find.widgetWithText(NexoButton, 'Criar conta'));
      expect(find.text('Crie sua conta'), findsOneWidget);
    }

    Future<void> fillValid(WidgetTester tester, {String? email}) async {
      await _type(tester, 'Nome', 'Ana');
      await _type(tester, 'Data de nascimento', '21032004');
      await _type(tester, 'E-mail', email ?? 'nova.conta@email.com');
      await _type(tester, 'Senha', 'Nexo#2026');
      await _blur(tester);
    }

    testWidgets('Criar conta fica desabilitado até tudo estar certo', (
      tester,
    ) async {
      await _pumpApp(tester);
      await openSignUp(tester);
      expect(_button(tester, 'Criar conta').onPressed, isNull);
      expect(
        find.text('Preencha os campos e marque o aceite para criar a conta.'),
        findsOneWidget,
      );
      // A regra de senha fica sempre à vista.
      expect(find.text(AuthMessages.passwordHelper), findsOneWidget);

      await fillValid(tester);
      expect(find.text('21/03/2004'), findsOneWidget, reason: 'máscara');
      expect(find.text('Marque o aceite para criar a conta.'), findsOneWidget);

      await _tap(tester, find.byType(NexoCheckbox));
      expect(_button(tester, 'Criar conta').onPressed, isNotNull);
    });

    testWidgets('erros de campo aparecem ao sair do campo', (tester) async {
      await _pumpApp(tester);
      await openSignUp(tester);
      await _type(tester, 'Nome', '');
      await _type(tester, 'Data de nascimento', '14052011');
      await _type(tester, 'E-mail', 'ana.souza@email');
      await _type(tester, 'Senha', 'abcd');
      await _blur(tester);

      expect(find.text(AuthMessages.nameEmpty), findsOneWidget);
      expect(find.text(AuthMessages.underage), findsOneWidget);
      expect(find.text(AuthMessages.emailInvalid), findsOneWidget);
      expect(find.text(AuthMessages.passwordInvalid), findsOneWidget);
      expect(
        find.text('Corrija os campos marcados e marque o aceite.'),
        findsOneWidget,
      );
    });

    testWidgets('e-mail já usado oferece entrar com ele', (tester) async {
      await _pumpApp(tester);
      await openSignUp(tester);
      await fillValid(tester, email: FakeAuthRepository.prototypeEmail);
      await _tap(tester, find.byType(NexoCheckbox));
      await _tap(tester, find.widgetWithText(NexoButton, 'Criar conta'));
      expect(find.text('Este e-mail já tem uma conta'), findsOneWidget);

      await _tap(
        tester,
        find.widgetWithText(NexoButton, 'Entrar com este e-mail'),
      );
      expect(find.text('Entre na sua conta'), findsOneWidget);
      expect(find.text(FakeAuthRepository.prototypeEmail), findsOneWidget);
    });

    testWidgets('conta nova grava o perfil com o aceite e vai à tela 05', (
      tester,
    ) async {
      final app = await _pumpApp(tester);
      await openSignUp(tester);
      await fillValid(tester);
      await _tap(tester, find.byType(NexoCheckbox));
      await _tap(tester, find.widgetWithText(NexoButton, 'Criar conta'));

      expect(find.text('Confirme seu e-mail'), findsOneWidget);
      expect(find.textContaining('nova.conta@email.com'), findsOneWidget);

      final uid = app.auth.currentUser!.uid;
      final profile = app.profiles.created[uid]!;
      expect(profile.displayName, 'Ana');
      expect(profile.birthDate.toIso(), '2004-03-21');
      expect(profile.timeZone, 'America/Sao_Paulo');
      expect(
        profile.consents.termsVersion,
        FakeLegalDocumentsRepository.current.termsVersion,
      );
      expect(
        profile.consents.privacyVersion,
        FakeLegalDocumentsRepository.current.privacyVersion,
      );
    });

    testWidgets('links dos Termos e da Política abrem e voltam', (
      tester,
    ) async {
      await _pumpApp(tester);
      await openSignUp(tester);
      await _tap(tester, find.widgetWithText(NexoButton, 'Termos de Uso'));
      expect(find.textContaining('terms-2026-11-01'), findsOneWidget);
      await _tap(tester, find.byTooltip('Voltar'));
      expect(find.text('Crie sua conta'), findsOneWidget);
    });
  });

  group('05 Verifique seu e-mail', () {
    const unverified = AuthUser(
      uid: 'nova',
      emailVerified: false,
      email: 'nova.conta@email.com',
    );

    testWidgets('1º "Já confirmei" avisa; reenviar conta 0:45', (tester) async {
      final app = await _pumpApp(tester);
      // A espera do fake só anda com o relógio do teste: dispara e avança.
      unawaited(
        app.auth.createAccount(
          email: 'nova.conta@email.com',
          password: 'Nexo#2026',
        ),
      );
      await tester.pumpAndSettle();
      app.profiles.setProfile(
        app.auth.currentUser!.uid,
        const UserProfile(displayName: 'Ana'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Confirme seu e-mail'), findsOneWidget);

      await _tap(tester, find.widgetWithText(NexoButton, 'Já confirmei'));
      expect(find.text('Ainda não encontramos a confirmação'), findsOneWidget);

      await _tap(tester, find.widgetWithText(NexoButton, 'Reenviar e-mail'));
      expect(find.text('E-mail reenviado.'), findsOneWidget);
      expect(find.text('Reenviar em 0:45'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      expect(find.text('Reenviar em 0:38'), findsOneWidget);
      await tester.pump(const Duration(seconds: 40));
      await tester.pumpAndSettle();

      // 2º "Já confirmei": confirmado, segue para o tutorial.
      await _tap(tester, find.widgetWithText(NexoButton, 'Já confirmei'));
      expect(find.text('Boas-vindas'), findsOneWidget);
    });

    testWidgets('"Usar outro e-mail" volta ao Cadastro', (tester) async {
      await _pumpApp(tester, user: unverified);
      await _tap(tester, find.widgetWithText(NexoButton, 'Usar outro e-mail'));
      expect(find.text('Crie sua conta'), findsOneWidget);
    });
  });

  group('04 Esqueci minha senha', () {
    Future<void> open(WidgetTester tester) async {
      await _pumpApp(tester);
      await _tap(
        tester,
        find.widgetWithText(NexoButton, 'Esqueci minha senha'),
      );
      expect(find.text('Redefina sua senha'), findsOneWidget);
    }

    testWidgets('erros de campo da spec', (tester) async {
      await open(tester);
      await _tap(tester, find.widgetWithText(NexoButton, 'Enviar link'));
      expect(find.text(AuthMessages.resetEmailEmpty), findsOneWidget);
      await _type(tester, 'E-mail', 'ana@email');
      await _tap(tester, find.widgetWithText(NexoButton, 'Enviar link'));
      expect(find.text(AuthMessages.resetEmailInvalid), findsOneWidget);
    });

    testWidgets('mensagem neutra e reenvio com 0:45', (tester) async {
      await open(tester);
      await _type(tester, 'E-mail', 'ninguem@email.com');
      await _tap(tester, find.widgetWithText(NexoButton, 'Enviar link'));
      expect(find.text('Confira seu e-mail'), findsOneWidget);
      expect(
        find.textContaining('Se houver uma conta com ninguem@email.com'),
        findsOneWidget,
      );
      expect(find.text('Reenviar em 0:45'), findsOneWidget);

      await tester.pump(const Duration(seconds: 45));
      await _tap(tester, find.widgetWithText(NexoButton, 'Reenviar link'));
      expect(find.text('Link reenviado.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 45));
      await tester.pumpAndSettle();
    });

    testWidgets('sem conexão oferece tentar de novo', (tester) async {
      await open(tester);
      await _type(tester, 'E-mail', 'sem-conexao@email.com');
      await _tap(tester, find.widgetWithText(NexoButton, 'Enviar link'));
      expect(find.text('Você está sem conexão'), findsOneWidget);
      expect(find.widgetWithText(NexoButton, 'Tentar de novo'), findsOneWidget);
    });
  });

  group('03b Primeiro acesso com Google', () {
    Future<_App> openGoogle(WidgetTester tester) async {
      final app = await _pumpApp(tester);
      await _tap(tester, find.byType(NexoGoogleButton));
      expect(find.text('Falta pouco'), findsOneWidget);
      expect(find.text(FakeAuthRepository.googleEmail), findsOneWidget);
      // Nome vindo do Google, editável.
      expect(find.text('Ana Souza'), findsOneWidget);
      return app;
    }

    testWidgets('data e aceite criam o perfil e seguem para o tutorial', (
      tester,
    ) async {
      final app = await openGoogle(tester);
      expect(_button(tester, 'Continuar').onPressed, isNull);
      await _type(tester, 'Data de nascimento', '21032004');
      await _tap(tester, find.byType(NexoCheckbox));
      await _tap(tester, find.widgetWithText(NexoButton, 'Continuar'));

      expect(find.text('Boas-vindas'), findsOneWidget);
      expect(app.profiles.created.values.single.displayName, 'Ana Souza');
    });

    testWidgets('menor de 16: apaga a conta e avisa no Login', (tester) async {
      final app = await openGoogle(tester);
      await _type(tester, 'Data de nascimento', '14052011');
      expect(find.text(AuthMessages.underage), findsOneWidget);
      await _tap(tester, find.byType(NexoCheckbox));
      await _tap(tester, find.widgetWithText(NexoButton, 'Continuar'));

      expect(app.auth.currentUser, isNull);
      expect(app.profiles.created, isEmpty);
      expect(find.text('Entre na sua conta'), findsOneWidget);
      // Alerta que some em 5 s.
      expect(find.text('Conta não criada'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Conta não criada'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Conta não criada'), findsNothing);
    });

    testWidgets('voltar apaga a conta e volta ao Login', (tester) async {
      final app = await openGoogle(tester);
      expect(find.text('Cancelar e sair'), findsNothing);
      await _tap(tester, find.byTooltip('Voltar'));
      expect(app.auth.currentUser, isNull);
      expect(find.text('Entre na sua conta'), findsOneWidget);
    });
  });
}
