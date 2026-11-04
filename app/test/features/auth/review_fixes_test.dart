import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/data/data_failure.dart';
import 'package:nexo/core/data/local_flags.dart';
import 'package:nexo/core/ui/ui.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/application/sign_up_controller.dart';
import 'package:nexo/features/auth/data/fake_auth_repository.dart';
import 'package:nexo/features/auth/domain/auth_user.dart';
import 'package:nexo/features/legal/data/legal_documents_repository.dart';

/// Testes dos achados da revisão de código de 04/11/2026.

/// Perfil que só grava quando [gate] completa.
class _SlowProfiles extends FakeUserProfileRepository {
  final gate = Completer<void>();

  @override
  Future<void> createProfile(String uid, NewUserProfile profile) async {
    await gate.future;
    return super.createProfile(uid, profile);
  }
}

/// Perfil que nunca grava (sem conexão), depois de [delay].
class _FailingProfiles extends FakeUserProfileRepository {
  _FailingProfiles({this.delay = Duration.zero});

  final Duration delay;
  var calls = 0;

  @override
  Future<void> createProfile(String uid, NewUserProfile profile) async {
    calls++;
    await Future<void>.delayed(delay);
    throw const DataFailure(DataFailureCode.network);
  }
}

class _FailingLegal implements LegalDocumentsRepository {
  @override
  Future<Consents> currentVersions() async =>
      throw const DataFailure(DataFailureCode.network);
}

/// Conta quantos e-mails de verificação o app pediu.
class _CountingAuth extends FakeAuthRepository {
  _CountingAuth() : super(withPrototypeAccounts: true);

  var verifications = 0;

  @override
  Future<void> sendEmailVerification() async {
    verifications++;
    return super.sendEmailVerification();
  }
}

const _google = AuthUser(
  uid: 'google-ana',
  emailVerified: true,
  signedInWithGoogle: true,
  email: FakeAuthRepository.googleEmail,
  displayName: 'Ana Souza',
);

Future<void> _pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  FakeUserProfileRepository? profiles,
  LegalDocumentsRepository? legal,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userProfileRepositoryProvider.overrideWithValue(
          profiles ?? FakeUserProfileRepository.prototype(),
        ),
        if (legal != null)
          legalDocumentsRepositoryProvider.overrideWithValue(legal),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 4, 12)),
        localFlagsProvider.overrideWithValue(
          InMemoryLocalFlags(firstOpenDone: true),
        ),
      ],
      child: const NexoApp(),
    ),
  );
  await tester.pumpAndSettle();
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

NexoButton _button(WidgetTester tester, String label) =>
    tester.widget<NexoButton>(find.widgetWithText(NexoButton, label));

Future<void> _fillSignUp(WidgetTester tester, {required String email}) async {
  await _tap(tester, find.widgetWithText(NexoButton, 'Criar conta'));
  await _type(tester, 'Nome', 'Ana');
  await _type(tester, 'Data de nascimento', '21032004');
  await _type(tester, 'E-mail', email);
  await _type(tester, 'Senha', 'Nexo#2026');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await _tap(tester, find.byType(NexoCheckbox));
}

Future<void> _fillGoogleFirstAccess(WidgetTester tester) async {
  await _type(tester, 'Data de nascimento', '21032004');
  await _tap(tester, find.byType(NexoCheckbox));
}

void main() {
  testWidgets(
    '[1] 03b: voltar durante a gravação do perfil não apaga a conta',
    (tester) async {
      final auth = FakeAuthRepository(initialUser: _google);
      final profiles = _SlowProfiles();
      await _pumpApp(tester, auth: auth, profiles: profiles);
      expect(find.text('Falta pouco'), findsOneWidget);

      await _fillGoogleFirstAccess(tester);
      await tester.tap(find.widgetWithText(NexoButton, 'Continuar'));
      await tester.pump();

      // Gravando: sem seta de voltar, e o voltar do Android é ignorado.
      expect(find.byTooltip('Voltar'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(auth.currentUser, isNotNull);

      profiles.gate.complete();
      await tester.pumpAndSettle();
      expect(auth.currentUser, isNotNull);
      expect(profiles.created, contains(_google.uid));
      expect(find.text('Objetivo e plano'), findsOneWidget);
    },
  );

  testWidgets('[2] 03b: falha ao gravar o perfil solta o botão e avisa', (
    tester,
  ) async {
    final profiles = _FailingProfiles();
    await _pumpApp(
      tester,
      auth: FakeAuthRepository(initialUser: _google),
      profiles: profiles,
    );
    await _fillGoogleFirstAccess(tester);
    await _tap(tester, find.widgetWithText(NexoButton, 'Continuar'));

    expect(find.text('Você está sem conexão'), findsOneWidget);
    expect(_button(tester, 'Continuar').loading, isFalse);
    expect(_button(tester, 'Continuar').onPressed, isNotNull);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('[2] Cadastro: falha nas versões legais solta o botão e avisa', (
    tester,
  ) async {
    await _pumpApp(tester, auth: _CountingAuth(), legal: _FailingLegal());
    await _fillSignUp(tester, email: 'nova.conta@email.com');
    await _tap(tester, find.widgetWithText(NexoButton, 'Criar conta'));

    expect(find.text('Você está sem conexão'), findsOneWidget);
    expect(_button(tester, 'Criar conta').loading, isFalse);
    expect(find.text('Crie sua conta'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets(
    '[2] Cadastro: conta sem perfil é desfeita; aviso no próprio Cadastro',
    (tester) async {
      final auth = _CountingAuth();
      final profiles = _FailingProfiles();
      await _pumpApp(tester, auth: auth, profiles: profiles);
      await _fillSignUp(tester, email: 'nova.conta@email.com');
      await _tap(tester, find.widgetWithText(NexoButton, 'Criar conta'));

      // Tentou gravar duas vezes e desfez a conta.
      expect(profiles.calls, 2);
      expect(auth.currentUser, isNull);
      // A falha veio antes de o roteador sair do Cadastro: o aviso fica
      // nele, com os dados digitados.
      expect(find.text('Crie sua conta'), findsOneWidget);
      expect(find.text('Você está sem conexão'), findsOneWidget);
      expect(find.text('nova.conta@email.com'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets(
    '[2] Cadastro: falha depois de ir à tela 05 desfaz a conta e avisa no Login',
    (tester) async {
      final auth = _CountingAuth();
      final profiles = _FailingProfiles(
        delay: const Duration(milliseconds: 500),
      );
      await _pumpApp(tester, auth: auth, profiles: profiles);
      await _fillSignUp(tester, email: 'nova.conta@email.com');
      await _tap(tester, find.widgetWithText(NexoButton, 'Criar conta'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(profiles.calls, 2);
      expect(auth.currentUser, isNull);
      expect(find.text('Entre na sua conta'), findsOneWidget);
      expect(find.text('Não foi possível criar sua conta'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets('[5] Cadastro não pede um segundo e-mail de verificação', (
    tester,
  ) async {
    final auth = _CountingAuth();
    await _pumpApp(tester, auth: auth);
    await _fillSignUp(tester, email: 'nova.conta@email.com');
    await _tap(tester, find.widgetWithText(NexoButton, 'Criar conta'));

    expect(find.text('Confirme seu e-mail'), findsOneWidget);
    // O envio fica dentro do createAccount (repositório).
    expect(auth.verifications, 0);
  });

  testWidgets('[14] Cadastro: no bloqueio, o Google continua liberado', (
    tester,
  ) async {
    await _pumpApp(tester, auth: _CountingAuth());
    await _fillSignUp(tester, email: 'muitas-tentativas@email.com');
    await _tap(tester, find.widgetWithText(NexoButton, 'Criar conta'));

    expect(find.text('Muitas tentativas'), findsOneWidget);
    expect(_button(tester, 'Criar conta').onPressed, isNull);
    expect(
      tester.widget<NexoGoogleButton>(find.byType(NexoGoogleButton)).onPressed,
      isNotNull,
    );
    await tester.pump(const Duration(seconds: 61));
  });

  test('[11] dica do Cadastro sem "campos marcados" se nada está marcado', () {
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 4, 12)),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(signUpControllerProvider, (_, _) {});
    addTearDown(sub.close);
    final controller = container.read(signUpControllerProvider.notifier);

    controller
      ..change(SignUpField.name, 'Ana')
      ..change(SignUpField.birthDate, '21/03/2004')
      ..change(SignUpField.email, 'ana@email') // inválido, ainda sem foco
      ..change(SignUpField.password, 'Nexo#2026')
      ..setAccepted(true);

    expect(controller.errorOf(SignUpField.email), isNull);
    expect(controller.hint, 'Confira os campos para criar a conta.');
  });
}
