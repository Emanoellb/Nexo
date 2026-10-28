import 'package:flutter/foundation.dart';

import '../../../core/domain/field_rules.dart';
import '../../../core/domain/local_date.dart';
import 'auth_rules.dart';

/// Usuário autenticado, independente do Firebase.
@immutable
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.emailVerified,
    this.signedInWithGoogle = false,
    this.email,
    this.displayName,
  });

  final String uid;

  /// Contas Google já chegam verificadas.
  final bool emailVerified;
  final bool signedInWithGoogle;

  /// E-mail da conta (texto da tela 05 e da 03b).
  final String? email;

  /// Nome vindo do provedor (Google), usado só para preencher a 03b.
  final String? displayName;

  AuthUser copyWith({bool? emailVerified}) => AuthUser(
    uid: uid,
    emailVerified: emailVerified ?? this.emailVerified,
    signedInWithGoogle: signedInWithGoogle,
    email: email,
    displayName: displayName,
  );

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.uid == uid &&
      other.emailVerified == emailVerified &&
      other.signedInWithGoogle == signedInWithGoogle &&
      other.email == email &&
      other.displayName == displayName;

  @override
  int get hashCode =>
      Object.hash(uid, emailVerified, signedInWithGoogle, email, displayName);
}

/// Recorte de `users/{uid}` usado na entrada. Os demais campos do contrato
/// (firestore-rules.md §4) entram com as telas que os usam.
@immutable
class UserProfile {
  const UserProfile({required this.displayName, this.tutorialSeen = false});

  final String displayName;
  final bool tutorialSeen;

  UserProfile copyWith({String? displayName, bool? tutorialSeen}) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      tutorialSeen: tutorialSeen ?? this.tutorialSeen,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.displayName == displayName &&
      other.tutorialSeen == tutorialSeen;

  @override
  int get hashCode => Object.hash(displayName, tutorialSeen);
}

/// Aceite dos Termos e da Política: as versões de `legalDocuments/current`.
/// `acceptedAt` é o horário do servidor, gravado pelo repositório.
@immutable
class Consents {
  const Consents({required this.termsVersion, required this.privacyVersion});

  final String termsVersion;
  final String privacyVersion;
}

/// O que o Cadastro e a 03b gravam ao criar `users/{uid}`. Recusa o que as
/// regras do Firestore recusariam (nome 1–80, 16+, ano ≥ 1900).
@immutable
class NewUserProfile {
  NewUserProfile({
    required String displayName,
    required this.birthDate,
    required this.timeZone,
    required this.consents,
    required LocalDate today,
  }) : displayName = checkText(
         displayName.trim(),
         'displayName',
         1,
         AuthRules.nameMaxLength,
       ) {
    if (!AuthRules.isPlausibleBirthDate(birthDate, today) ||
        !AuthRules.isOldEnough(birthDate, today)) {
      throw ArgumentError.value(birthDate, 'birthDate', 'precisa ter 16+');
    }
    checkText(timeZone, 'timeZone', 1, 64);
  }

  final String displayName;
  final LocalDate birthDate;

  /// Fuso IANA (ex.: `America/Sao_Paulo`).
  final String timeZone;
  final Consents consents;
}
