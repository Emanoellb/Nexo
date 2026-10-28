import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_rules.dart';
import 'auth_messages.dart';
import 'auth_providers.dart';

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
class ForgotPasswordController extends Notifier<ForgotPasswordState> {
  late final Countdown _resend;
  late final Countdown _lock;
  final _alertTimer = AlertTimer();

  @override
  ForgotPasswordState build() {
    _resend = Countdown((s) {
      if (ref.mounted) state = state.copyWith(resendIn: s);
    });
    _lock = Countdown((s) {
      if (!ref.mounted) return;
      // Fim do bloqueio: o "Muitas tentativas" sai junto.
      state = state.copyWith(
        lockedFor: s,
        alert: s <= 0 && state.alert == ForgotPasswordAlert.tooManyRequests
            ? () => null
            : null,
      );
    });
    ref.onDispose(() {
      _resend.cancel();
      _lock.cancel();
      _alertTimer.cancel();
    });
    return const ForgotPasswordState();
  }

  /// Tira o alerta depois de 5 s, se ainda for o mesmo (decisão do usuário,
  /// 27/10/2026).
  void _expireAlert() {
    final alert = state.alert;
    if (alert == null) return;
    _alertTimer.start(() {
      if (ref.mounted && state.alert == alert) {
        state = state.copyWith(alert: () => null);
      }
    });
  }

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
    final trimmed = email.trim();
    final error = trimmed.isEmpty
        ? AuthMessages.resetEmailEmpty
        : !AuthRules.isValidEmail(trimmed)
        ? AuthMessages.resetEmailInvalid
        : null;
    if (error != null) {
      state = state.copyWith(emailError: () => error, alert: () => null);
      return false;
    }

    final auth = ref.read(authRepositoryProvider);
    state = state.copyWith(sending: true, alert: () => null);
    try {
      await auth.sendPasswordResetEmail(trimmed);
      if (!ref.mounted) return true;
      state = state.copyWith(sending: false, sentTo: trimmed);
      _resend.start(resendCooldownSeconds);
      return true;
    } on AuthFailure catch (failure) {
      if (!ref.mounted) return false;
      switch (failure.code) {
        case AuthFailureCode.invalidEmail:
          state = state.copyWith(
            sending: false,
            emailError: () => AuthMessages.resetEmailInvalid,
          );
        case AuthFailureCode.network:
          state = state.copyWith(
            sending: false,
            alert: () => ForgotPasswordAlert.offline,
          );
          _expireAlert();
        case AuthFailureCode.tooManyRequests:
          state = state.copyWith(
            sending: false,
            alert: () => ForgotPasswordAlert.tooManyRequests,
          );
          // Fica os 60 s do bloqueio, não os 5 s.
          _alertTimer.cancel();
          _lock.start(tooManyRequestsLockSeconds);
        default:
          state = state.copyWith(
            sending: false,
            alert: () => ForgotPasswordAlert.generic,
          );
          _expireAlert();
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
