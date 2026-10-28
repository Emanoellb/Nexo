import '../../../core/domain/local_date.dart';
import '../domain/auth_rules.dart';
import 'auth_messages.dart';

/// Validações dos campos de perfil, iguais no Cadastro (03) e na 03b.
abstract final class ProfileForm {
  static String? nameError(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return AuthMessages.nameEmpty;
    if (trimmed.length > AuthRules.nameMaxLength) {
      return AuthMessages.nameTooLong;
    }
    return null;
  }

  /// `DD/MM/AAAA` lido como data, ou `null` se incompleta ou inexistente.
  static LocalDate? parseBirthDate(String value, LocalDate today) {
    try {
      final date = LocalDate.parseDisplay(value);
      return AuthRules.isPlausibleBirthDate(date, today) ? date : null;
    } on FormatException {
      return null;
    }
  }

  /// Erro do campo de data. Com [checkAge], inclui o "16 anos ou mais".
  static String? birthDateError(
    String value,
    LocalDate today, {
    bool checkAge = true,
  }) {
    if (value.trim().isEmpty) return AuthMessages.birthDateEmpty;
    final date = parseBirthDate(value, today);
    if (date == null) return AuthMessages.birthDateInvalid;
    if (checkAge && !AuthRules.isOldEnough(date, today)) {
      return AuthMessages.underage;
    }
    return null;
  }

  static String? emailError(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return AuthMessages.emailEmpty;
    if (!AuthRules.isValidEmail(trimmed)) return AuthMessages.emailInvalid;
    return null;
  }

  static String? passwordError(String value) {
    if (value.isEmpty) return AuthMessages.passwordEmptySignUp;
    if (!AuthRules.meetsPasswordPolicy(value)) {
      return AuthMessages.passwordInvalid;
    }
    return null;
  }
}
