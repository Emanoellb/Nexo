import 'package:flutter/foundation.dart';

/// Usuário autenticado, independente do Firebase.
@immutable
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.emailVerified,
    this.signedInWithGoogle = false,
  });

  final String uid;

  /// Contas Google já chegam verificadas.
  final bool emailVerified;
  final bool signedInWithGoogle;

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.uid == uid &&
      other.emailVerified == emailVerified &&
      other.signedInWithGoogle == signedInWithGoogle;

  @override
  int get hashCode => Object.hash(uid, emailVerified, signedInWithGoogle);
}

/// Recorte de `users/{uid}` usado na entrada. Os demais campos do contrato
/// (firestore-rules.md §4) entram com o fluxo de cadastro.
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
