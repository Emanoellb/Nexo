import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/features/auth/domain/auth_failure.dart';

import '../../fakes/fakes.dart';

Matcher _fails(AuthFailureCode code) =>
    throwsA(isA<AuthFailure>().having((f) => f.code, 'code', code));

void main() {
  late FakeAuthRepository auth;

  setUp(() {
    auth = FakeAuthRepository(withPrototypeAccounts: true);
    addTearDown(auth.dispose);
  });

  test('entra com a conta pronta', () async {
    await auth.signInWithEmail(
      email: FakeAuthRepository.prototypeEmail,
      password: FakeAuthRepository.prototypePassword,
    );
    expect(auth.currentUser, FakeAuthRepository.prototypeUser);
  });

  test('senha errada: invalid-credential; na 6ª tentativa, bloqueio', () async {
    for (var i = 0; i < FakeAuthRepository.maxFailedAttempts; i++) {
      await expectLater(
        auth.signInWithEmail(
          email: FakeAuthRepository.prototypeEmail,
          password: 'Errada#123',
        ),
        _fails(AuthFailureCode.invalidCredential),
      );
    }
    await expectLater(
      auth.signInWithEmail(
        email: FakeAuthRepository.prototypeEmail,
        password: FakeAuthRepository.prototypePassword,
      ),
      _fails(AuthFailureCode.tooManyRequests),
    );
  });

  test('e-mails gatilho', () async {
    await expectLater(
      auth.signInWithEmail(email: 'sem-conexao@email.com', password: 'x'),
      _fails(AuthFailureCode.network),
    );
    await expectLater(
      auth.sendPasswordResetEmail('muitas-tentativas@email.com'),
      _fails(AuthFailureCode.tooManyRequests),
    );
    await expectLater(
      auth.createAccount(email: 'erro@email.com', password: 'Nexo#2026'),
      _fails(AuthFailureCode.unknown),
    );
  });

  test('redefinição é neutra: conta inexistente também dá certo', () async {
    await auth.sendPasswordResetEmail('ninguem@email.com');
  });

  test('cadastro: e-mail já usado e conta nova sem verificação', () async {
    await expectLater(
      auth.createAccount(
        email: FakeAuthRepository.prototypeEmail,
        password: 'Nexo#2026',
      ),
      _fails(AuthFailureCode.emailAlreadyInUse),
    );

    await auth.createAccount(email: 'nova@email.com', password: 'Nexo#2026');
    expect(auth.currentUser!.emailVerified, isFalse);
    expect(auth.currentUser!.email, 'nova@email.com');

    // 1º "Já confirmei" ainda não encontra; o 2º confirma.
    expect(await auth.refreshEmailVerified(), isFalse);
    expect(await auth.refreshEmailVerified(), isTrue);
    expect(auth.currentUser!.emailVerified, isTrue);
  });

  test('Google devolve a conta fixa; apagar encerra a sessão', () async {
    final user = await auth.signInWithGoogle();
    expect(user!.email, FakeAuthRepository.googleEmail);
    expect(user.signedInWithGoogle, isTrue);
    await auth.deleteCurrentUser();
    expect(auth.currentUser, isNull);
    // A conta fictícia segue disponível para um novo teste.
    expect(await auth.signInWithGoogle(), isNotNull);
  });
}
