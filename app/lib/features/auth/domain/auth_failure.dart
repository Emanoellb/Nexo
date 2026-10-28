/// Falhas do auth que a interface trata, independentes do Firebase.
enum AuthFailureCode {
  /// E-mail ou senha incorretos. Com a enumeration protection, o Firebase
  /// não diz qual dos dois (firebase-setup.md §6.0).
  invalidCredential,
  tooManyRequests,
  network,

  /// Só o cadastro revela isso, mesmo com a proteção ligada.
  emailAlreadyInUse,
  invalidEmail,
  weakPassword,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.code);

  final AuthFailureCode code;

  @override
  String toString() => 'AuthFailure(${code.name})';
}

/// Converte o `FirebaseAuthException.code` em [AuthFailureCode]. O código
/// pode vir com ou sem o prefixo `auth/` (auth-redefinicao-senha.md §7).
AuthFailureCode authFailureFromCode(String code) {
  final normalized = code.startsWith('auth/') ? code.substring(5) : code;
  return switch (normalized) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'invalid-login-credentials' => AuthFailureCode.invalidCredential,
    'too-many-requests' => AuthFailureCode.tooManyRequests,
    'network-request-failed' => AuthFailureCode.network,
    'email-already-in-use' => AuthFailureCode.emailAlreadyInUse,
    'invalid-email' => AuthFailureCode.invalidEmail,
    'weak-password' ||
    'password-does-not-meet-requirements' => AuthFailureCode.weakPassword,
    _ => AuthFailureCode.unknown,
  };
}
