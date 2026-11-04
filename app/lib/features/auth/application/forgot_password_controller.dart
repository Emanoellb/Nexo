import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_failure.dart';
import 'auth_messages.dart';
import 'auth_providers.dart';
import 'entry_alerts.dart';
import 'profile_form.dart';

enum ForgotPasswordAlert { offline, tooManyRequests, generic }

@immutable
class ForgotPasswordState {
  const ForgotPasswordState({
    this.emailError,
    this.sending = false,
    this.sentTo,
    this.resendIn = 0,
    this.lockedFor = 0,
    this.alert,
  });

  final String? emailError;
  final bool sending;

  /// E-mail do estado "Link enviado"; `null` no formulário.
  final String? sentTo;

  /// Segundos até poder reenviar (0:45).
  final int resendIn;

  /// Segundos de bloqueio depois de "Muitas tentativas" (60 s).
  final int lockedFor;
  final ForgotPasswordAlert? alert;

  ForgotPasswordState copyWith({
    String? Function()? emailError,
    bool? sending,
    String? sentTo,
    int? resendIn,
    int? lockedFor,
    ForgotPasswordAlert? Function()? alert,
  }) => ForgotPasswordState(
    emailError: emailError == null ? this.emailError : emailError(),
    sending: sending ?? this.sending,
    sentTo: sentTo ?? this.sentTo,
    resendIn: resendIn ?? this.resendIn,
    lockedFor: lockedFor ?? this.lockedFor,
    alert: alert == null ? this.alert : alert(),
  );
}

/// Estado da tela 04 Esqueci minha senha (spec auth-redefinicao-senha.md §7).
/// A mensagem de sucesso é neutra: não diz se a conta existe.
class ForgotPasswordController extends Notifier<ForgotPasswordState>
    with EntryAlerts<ForgotPasswordState, ForgotPasswordAlert> {
  late final Countdown _resend;

  @override
  ForgotPasswordState build() {
    _resend = Countdown((s) {
      if (ref.mounted) state = state.copyWith(resendIn: s);
    });
    ref.onDispose(() {
      _resend.cancel();
      disposeAlerts();
    });
    return const ForgotPasswordState();
  }

  @override
  ForgotPasswordAlert? alertOf(ForgotPasswordState state) => state.alert;

  @override
  ForgotPasswordState withAlert(
    ForgotPasswordState state,
    ForgotPasswordAlert? alert,
  ) => state.copyWith(alert: () => alert);

  @override
  ForgotPasswordState withLock(ForgotPasswordState state, int seconds) =>
      state.copyWith(lockedFor: seconds);

  /// Editar tira o erro do campo e o erro genérico.
  void emailChanged() {
    final alert = state.alert == ForgotPasswordAlert.generic
        ? null
        : state.alert;
    if (state.emailError != null || alert != state.alert) {
      state = state.copyWith(emailError: () => null, alert: () => alert);
    }
  }

  /// Envia o link. Devolve `true` quando enviou.
  Future<bool> send(String email) async {
    if (state.sending || state.lockedFor > 0) return false;
    final error = ProfileForm.emailError(
      email,
      empty: AuthMessages.resetEmailEmpty,
      invalid: AuthMessages.resetEmailInvalid,
    );
    if (error != null) {
      state = state.copyWith(emailError: () => error, alert: () => null);
      return false;
    }

    final trimmed = email.trim();
    final auth = ref.read(authRepositoryProvider);
    state = state.copyWith(sending: true, alert: () => null);
    try {
      await auth.sendPasswordResetEmail(trimmed);
      if (!ref.mounted) return true;
      state = state.copyWith(sending: false, sentTo: trimmed);
      _resend.start(resendCooldownSeconds);
      return true;
    } catch (error, stack) {
      final code = failureCodeOf(error, stack);
      if (!ref.mounted) return false;
      state = state.copyWith(sending: false);
      switch (code) {
        case AuthFailureCode.invalidEmail:
          state = state.copyWith(
            emailError: () => AuthMessages.resetEmailInvalid,
          );
        case AuthFailureCode.network:
          showAlert(ForgotPasswordAlert.offline);
        case AuthFailureCode.tooManyRequests:
          startLock(ForgotPasswordAlert.tooManyRequests);
        default:
          showAlert(ForgotPasswordAlert.generic);
      }
      return false;
    }
  }

  /// "Reenviar" no estado Link enviado.
  Future<bool> resend() async {
    final email = state.sentTo;
    if (email == null || state.resendIn > 0) return false;
    return send(email);
  }
}

final forgotPasswordControllerProvider =
    NotifierProvider.autoDispose<ForgotPasswordController, ForgotPasswordState>(
      ForgotPasswordController.new,
    );
