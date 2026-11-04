import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_failure.dart';
import 'auth_messages.dart';
import 'auth_providers.dart';
import 'entry_alerts.dart';

enum VerifyEmailAlert { notConfirmedYet, offline, generic }

@immutable
class VerifyEmailState {
  const VerifyEmailState({
    this.checking = false,
    this.resending = false,
    this.resendIn = 0,
    this.alert,
  });

  final bool checking;
  final bool resending;
  final int resendIn;
  final VerifyEmailAlert? alert;

  VerifyEmailState copyWith({
    bool? checking,
    bool? resending,
    int? resendIn,
    VerifyEmailAlert? Function()? alert,
  }) => VerifyEmailState(
    checking: checking ?? this.checking,
    resending: resending ?? this.resending,
    resendIn: resendIn ?? this.resendIn,
    alert: alert == null ? this.alert : alert(),
  );
}

/// Estado da tela 05 Verifique seu e-mail (só contas de e-mail e senha).
class VerifyEmailController extends Notifier<VerifyEmailState>
    with EntryAlerts<VerifyEmailState, VerifyEmailAlert> {
  late final Countdown _resend;

  @override
  VerifyEmailState build() {
    _resend = Countdown((s) {
      if (ref.mounted) state = state.copyWith(resendIn: s);
    });
    ref.onDispose(() {
      _resend.cancel();
      disposeAlerts();
    });
    return const VerifyEmailState();
  }

  @override
  VerifyEmailAlert? alertOf(VerifyEmailState state) => state.alert;

  @override
  VerifyEmailState withAlert(VerifyEmailState state, VerifyEmailAlert? alert) =>
      state.copyWith(alert: () => alert);

  /// "Já confirmei": reload + token novo. Confirmado, o roteador segue.
  Future<void> confirm() async {
    if (state.checking) return;
    final auth = ref.read(authRepositoryProvider);
    state = state.copyWith(checking: true, alert: () => null);
    try {
      final verified = await auth.refreshEmailVerified();
      if (!ref.mounted) return;
      state = state.copyWith(checking: false);
      if (!verified) showAlert(VerifyEmailAlert.notConfirmedYet);
    } catch (error, stack) {
      _fail(failureCodeOf(error, stack));
    }
  }

  /// "Reenviar e-mail". Devolve `true` quando reenviou.
  Future<bool> resend() async {
    if (state.resending || state.resendIn > 0) return false;
    final auth = ref.read(authRepositoryProvider);
    state = state.copyWith(resending: true);
    try {
      await auth.sendEmailVerification();
      if (!ref.mounted) return true;
      state = state.copyWith(resending: false);
      _resend.start(resendCooldownSeconds);
      return true;
    } catch (error, stack) {
      _fail(failureCodeOf(error, stack));
      return false;
    }
  }

  /// "Usar outro e-mail": sai desta conta e volta ao Cadastro.
  Future<void> useAnotherEmail() => ref.read(authRepositoryProvider).signOut();

  void _fail(AuthFailureCode code) {
    if (!ref.mounted) return;
    state = state.copyWith(checking: false, resending: false);
    showAlert(
      code == AuthFailureCode.network
          ? VerifyEmailAlert.offline
          : VerifyEmailAlert.generic,
    );
  }
}

final verifyEmailControllerProvider =
    NotifierProvider.autoDispose<VerifyEmailController, VerifyEmailState>(
      VerifyEmailController.new,
    );
