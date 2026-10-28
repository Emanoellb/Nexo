import '../../../core/domain/local_date.dart';

/// Regras puras do fluxo de entrada (firebase-setup.md §6.1,
/// firestore-rules.md §4). As telas e os repositórios usam as mesmas.
abstract final class AuthRules {
  /// Idade mínima para usar o Nexo.
  static const minimumAge = 16;

  /// Ano mínimo aceito pelas regras do Firestore (`birthDate`).
  static const minimumBirthYear = 1900;

  /// Limite de `displayName`.
  static const nameMaxLength = 80;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  /// Caracteres especiais aceitos pela política de senha do Firebase
  /// (Password policy, "special character"). [NC] contra o console: a
  /// conferência final é o `validatePassword` no bloco de integração.
  static final _special = RegExp(
    r'''[\^$*.\[\]{}()?"!@#%&/\\,><':;|_~`=+\-]''',
  );

  /// Formato de e-mail (o Firebase confere o resto).
  static bool isValidEmail(String value) => _email.hasMatch(value.trim());

  /// Regra R5: 8+ caracteres, com maiúscula, minúscula, número e especial.
  static bool meetsPasswordPolicy(String value) =>
      value.length >= 8 &&
      value.contains(RegExp('[A-Z]')) &&
      value.contains(RegExp('[a-z]')) &&
      value.contains(RegExp('[0-9]')) &&
      value.contains(_special);

  /// Idade completa em [today].
  static int ageOn(LocalDate birthDate, LocalDate today) {
    var age = today.year - birthDate.year;
    final hadBirthday =
        today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hadBirthday) age--;
    return age;
  }

  /// 16 anos ou mais em [today].
  static bool isOldEnough(LocalDate birthDate, LocalDate today) =>
      ageOn(birthDate, today) >= minimumAge;

  /// Data plausível: a partir de 1900 e não no futuro.
  static bool isPlausibleBirthDate(LocalDate birthDate, LocalDate today) =>
      birthDate.year >= minimumBirthYear && !birthDate.isAfter(today);
}
