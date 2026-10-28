import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_rules.dart';
import 'auth_messages.dart';
import 'auth_providers.dart';

/// Avisos da tela 02 (Alert no topo do formulário). Ficam 5 s na tela
/// ([alertDuration]); "Muitas tentativas" fica os 60 s do bloqueio, com a
/// contagem (decisão do usuário, 27/10/2026). Editar um campo também tira
/// "incorretos" e o genérico.
enum LoginAlert {
  invalidCredential,
  offline,
  tooManyRequests,
  generic,

  /// A 03b recusou a idade e apagou a conta Google.
  underage,
}

@immutable
class LoginState {
  const LoginState({
    this.emailError,
    this.passwordError,
    this.alert,
    this.submitting = false,
    this.googleLoading = false,
    this.lockedFor = 0,
  });

  final String? emailError;
  final String? passwordError;
  final LoginAlert? alert;
  final bool submitting;
  final bool googleLoading;

  /// Segundos de bloqueio depois de "Muitas tentativas" (Entrar
  /// desabilitado).
  final int lockedFor;

  bool get locked => lockedFor > 0;
  bool get busy => submitting || googleLoading;

  LoginState copyWith({
    String? Function()? emailError,
    String? Function()? passwordError,
    LoginAlert? Function()? alert,
    bool? submitting,
    bool? googleLoading,
    int? lockedFor,
  }) => LoginState(
    emailError: emailError == null ? this.emailError : emailError(),
    passwordError: passwordError == null ? this.passwordError : passwordError(),
    alert: alert == null ? this.alert : alert(),
    submitting: submitting ?? this.submitting,
    googleLoading: googleLoading ?? this.googleLoading,
    lockedFor: lockedFor ?? this.lockedFor,
  );
}

/// Estado da tela 02 Login. Valida ao tocar em Entrar (como no .pen); a
/// navegação depois do login fica com o redirecionamento do roteador.
class LoginController extends Notifier<LoginState> {
  late final Countdown _lock;
  final _alertTimer = AlertTimer();

  @override
  LoginState build() {
    _lock = Countdown((remaining) {
      if (!ref.mounted) return;
      // Fim do bloqueio: Entrar volta e o alerta sai.
      state = state.copyWith(
        lockedFor: remaining,
        alert: remaining <= 0 && state.alert == LoginAlert.tooManyRequests
            ? () => null
            : null,
      );
    });
    ref.onDispose(() {
      _lock.cancel();
      _alertTimer.cancel();
    });
    return const LoginState();
  }

  /// Mostra [alert] e o tira depois de 5 s, se ainda for o mesmo.
  void _showAlert(LoginAlert alert) {
    state = state.copyWith(alert: () => alert);
    _alertTimer.start(() {
      if (ref.mounted && state.alert == alert) {
        state = state.copyWith(alert: () => null);
      }
    });
  }

  /// Aviso vindo de outra tela (ex.: a 03b apagou a conta).
  void showEntryNotice(EntryNoticeKind notice) => _showAlert(switch (notice) {
    EntryNoticeKind.underage => LoginAlert.underage,
  });

  /// Editar um campo tira o erro dele e os alertas que pedem correção.
  LoginAlert? Function() get _alertAfterEdit =>
      () => switch (state.alert) {
        LoginAlert.invalidCredential || LoginAlert.generic => null,
        final other => other,
      };

  void emailChanged() =>
      state = state.copyWith(emailError: () => null, alert: _alertAfterEdit);

  void passwordChanged() =>
      state = state.copyWith(passwordError: () => null, alert: _alertAfterEdit);

  Future<void> submit({required String email, required String password}) async {
    if (state.busy || state.locked) return;

    final trimmed = email.trim();
    final emailError = trimmed.isEmpty
        ? AuthMessages.emailEmpty
        : !AuthRules.isValidEmail(trimmed)
        ? AuthMessages.emailInvalid
        : null;
    final passwordError = password.isEmpty
        ? AuthMessages.passwordEmptyLogin
        : null;
    if (emailError != null || passwordError != null) {
      state = state.copyWith(
        emailError: () => emailError,
        passwordError: () => passwordError,
        alert: () => null,
      );
      return;
    }

    final auth = ref.read(authRepositoryProvider);
    state = state.copyWith(submitting: true, alert: () => null);
    try {
      await auth.signInWithEmail(email: trimmed, password: password);
      if (ref.mounted) state = state.copyWith(submitting: false);
    } on AuthFailure catch (failure) {
      _fail(failure.code);
    }
  }

  Future<void> signInWithGoogle() async {
    if (state.busy) return;
    final auth = ref.read(authRepositoryProvider);
    state = state.copyWith(googleLoading: true, alert: () => null);
    try {
      await auth.signInWithGoogle();
      if (ref.mounted) state = state.copyWith(googleLoading: false);
    } on AuthFailure catch (failure) {
      _fail(failure.code);
    }
  }

  void _fail(AuthFailureCode code) {
    if (!ref.mounted) return;
    state = state.copyWith(submitting: false, googleLoading: false);
    if (code == AuthFailureCode.tooManyRequests) {
      _alertTimer.cancel();
      state = state.copyWith(alert: () => LoginAlert.tooManyRequests);
      _lock.start(tooManyRequestsLockSeconds);
      return;
    }
    _showAlert(switch (code) {
      AuthFailureCode.invalidCredential => LoginAlert.invalidCredential,
      AuthFailureCode.network => LoginAlert.offline,
      _ => LoginAlert.generic,
    });
  }
}

final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginState>(
      LoginController.new,
    );

/// Aviso levado de outra tela para o Login, mostrado como alerta que some
/// sozinho.
enum EntryNoticeKind {
  /// A 03b recusou a idade e apagou a conta Google.
  underage,
}

class EntryNotice extends Notifier<EntryNoticeKind?> {
  @override
  EntryNoticeKind? build() => null;

  void show(EntryNoticeKind notice) => state = notice;

  void clear() => state = null;
}

final entryNoticeProvider = NotifierProvider<EntryNotice, EntryNoticeKind?>(
  EntryNotice.new,
);
