/// Validações de campo iguais às das regras publicadas (`firestore.rules`):
/// o app recusa antes o que o banco recusaria depois.
library;

/// Texto entre [min] e [max] caracteres (`isText`).
String checkText(String value, String field, int min, int max) {
  if (value.length < min || value.length > max) {
    throw ArgumentError.value(
      value,
      field,
      'precisa ter de $min a $max caracteres',
    );
  }
  return value;
}

/// Texto opcional (`isTextOrNull`).
String? checkTextOrNull(String? value, String field, int min, int max) =>
    value == null ? null : checkText(value, field, min, max);

/// Inteiro entre [min] e [max] (`isIntBetween`).
int checkIntBetween(int value, String field, int min, int max) {
  if (value < min || value > max) {
    throw ArgumentError.value(value, field, 'precisa estar entre $min e $max');
  }
  return value;
}

/// Horário `HH:mm` em 24 h (`isTime`).
String checkTime(String value, String field) {
  if (!RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(value)) {
    throw ArgumentError.value(value, field, 'use HH:mm');
  }
  return value;
}
