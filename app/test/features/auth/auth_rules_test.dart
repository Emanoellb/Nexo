import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/auth/application/auth_messages.dart';
import 'package:nexo/features/auth/application/profile_form.dart';
import 'package:nexo/features/auth/domain/auth_failure.dart';
import 'package:nexo/features/auth/domain/auth_rules.dart';
import 'package:nexo/features/auth/domain/auth_user.dart';

const _today = LocalDate(2026, 10, 27);

void main() {
  group('senha R5', () {
    test('aceita 8+ com maiúscula, minúscula, número e especial', () {
      expect(AuthRules.meetsPasswordPolicy('Nexo#2026'), isTrue);
      expect(AuthRules.meetsPasswordPolicy('aB3!efgh'), isTrue);
    });

    test('recusa quando falta qualquer requisito', () {
      expect(AuthRules.meetsPasswordPolicy('Nx#2026'), isFalse, reason: '7');
      expect(AuthRules.meetsPasswordPolicy('nexo#2026'), isFalse);
      expect(AuthRules.meetsPasswordPolicy('NEXO#2026'), isFalse);
      expect(AuthRules.meetsPasswordPolicy('Nexo#nexo'), isFalse);
      expect(AuthRules.meetsPasswordPolicy('Nexo20266'), isFalse);
    });
  });

  test('formato de e-mail', () {
    expect(AuthRules.isValidEmail('ana.souza@email.com'), isTrue);
    expect(AuthRules.isValidEmail(' ana@email.com '), isTrue);
    expect(AuthRules.isValidEmail('ana.souza@email'), isFalse);
    expect(AuthRules.isValidEmail('ana souza@email.com'), isFalse);
    expect(AuthRules.isValidEmail(''), isFalse);
  });

  group('idade', () {
    test('16 anos completam no dia do aniversário', () {
      expect(
        AuthRules.isOldEnough(const LocalDate(2010, 10, 27), _today),
        true,
      );
      expect(
        AuthRules.isOldEnough(const LocalDate(2010, 10, 28), _today),
        false,
      );
    });

    test('nascido em 29/02 faz aniversário em 01/03 nos anos comuns', () {
      expect(
        AuthRules.ageOn(
          const LocalDate(2008, 2, 29),
          const LocalDate(2024, 2, 28),
        ),
        15,
      );
      expect(
        AuthRules.ageOn(
          const LocalDate(2008, 2, 29),
          const LocalDate(2024, 2, 29),
        ),
        16,
      );
    });

    test('mensagens do campo de data', () {
      expect(
        ProfileForm.birthDateError('', _today),
        AuthMessages.birthDateEmpty,
      );
      expect(
        ProfileForm.birthDateError('31/02/2004', _today),
        AuthMessages.birthDateInvalid,
      );
      expect(
        ProfileForm.birthDateError('01/01/1899', _today),
        AuthMessages.birthDateInvalid,
      );
      expect(
        ProfileForm.birthDateError('14/05/2011', _today),
        AuthMessages.underage,
      );
      expect(ProfileForm.birthDateError('21/03/2004', _today), isNull);
    });
  });

  test('NewUserProfile recusa o que as regras do Firestore recusam', () {
    NewUserProfile build({String name = 'Ana', LocalDate? birth}) =>
        NewUserProfile(
          displayName: name,
          birthDate: birth ?? const LocalDate(2004, 3, 21),
          timeZone: 'America/Sao_Paulo',
          consents: const Consents(termsVersion: 't', privacyVersion: 'p'),
          today: _today,
        );
    expect(build().displayName, 'Ana');
    expect(() => build(name: '  '), throwsArgumentError);
    expect(() => build(name: 'x' * 81), throwsArgumentError);
    expect(
      () => build(birth: const LocalDate(2011, 5, 14)),
      throwsArgumentError,
    );
  });

  test('códigos do Firebase com e sem o prefixo auth/', () {
    expect(
      authFailureFromCode('auth/invalid-credential'),
      AuthFailureCode.invalidCredential,
    );
    expect(
      authFailureFromCode('invalid-credential'),
      AuthFailureCode.invalidCredential,
    );
    expect(
      authFailureFromCode('too-many-requests'),
      AuthFailureCode.tooManyRequests,
    );
    expect(
      authFailureFromCode('auth/network-request-failed'),
      AuthFailureCode.network,
    );
    expect(
      authFailureFromCode('email-already-in-use'),
      AuthFailureCode.emailAlreadyInUse,
    );
    expect(authFailureFromCode('qualquer-outro'), AuthFailureCode.unknown);
  });
}
