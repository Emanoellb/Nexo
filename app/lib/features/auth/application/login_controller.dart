import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_failure.dart';
import 'auth_messages.dart';
import 'auth_providers.dart';
import 'entry_alerts.dart';
import 'profile_form.dart';

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

  /// O Cadastro criou a conta, mas não conseguiu gravar o perfil.
  signUpFailed,
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
class LoginController extends Notifier<LoginState>
    with EntryAlerts<LoginState, LoginAlert> {
  @override
  LoginState build() {
    ref.onDispose(disposeAlerts);
    return const LoginState();
  }

  @override
  LoginAlert? alertOf(LoginState state) => state.alert;

  @override
  LoginState withAlert(LoginState state, LoginAlert? alert) =>
      state.copyWith(alert: () => alert);

  @override
  LoginState withLock(LoginState state, int seconds) =>
      state.copyWith(lockedFor: seconds);

  /// Aviso vindo de outra tela (ex.: a 03b apagou a conta).
  void showEntryNotice(EntryNoticeKind notice) => showAlert(switch (notice) {
    EntryNoticeKind.underage => LoginAlert.underage,
    EntryNoticeKind.signUpFailed => LoginAlert.signUpFailed,
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

    final emailError = ProfileForm.emailError(email);
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
      await auth.signInWithEmail(email: email.trim(), password: password);
      if (ref.mounted) state = state.copyWith(submitting: false);
    } catch (error, stack) {
      _fail(failureCodeOf(error, stack));
    }
  }

  /// O bloqueio de "Muitas tentativas" vale só para e-mail e senha: o Google
  /// é outro caminho de entrada (decisão do usuário, 04/11/2026).
  Future<void> signInWithGoogle() async {
    if (state.busy) return;
    final auth = ref.read(authRepositoryProvider);
    // Durante o bloqueio, o "Muitas tentativas" fica: ele explica o botão
    // desabilitado.
    state = state.copyWith(googleLoading: true, alert: () => restingAlert);
    try {
      await auth.signInWithGoogle();
      if (ref.mounted) state = state.copyWith(googleLoading: false);
    } catch (error, stack) {
      _fail(failureCodeOf(error, stack));
    }
  }

  void _fail(AuthFailureCode code) {
    if (!ref.mounted) return;
    state = state.copyWith(submitting: false, googleLoading: false);
    if (code == AuthFailureCode.tooManyRequests) {
      startLock(LoginAlert.tooManyRequests);
      return;
    }
    showAlert(switch (code) {
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

  /// O Cadastro criou a conta no Auth, mas o perfil não foi gravado; a conta
  /// foi desfeita (achado [2] da revisão, 04/11/2026).
  signUpFailed,
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
