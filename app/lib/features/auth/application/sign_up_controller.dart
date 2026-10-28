import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../../../core/domain/local_date.dart';
import '../../legal/data/legal_documents_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_user.dart';
import 'auth_messages.dart';
import 'auth_providers.dart';
import 'profile_form.dart';

enum SignUpField { name, birthDate, email, password }

/// Avisos da tela 03 (Alert no topo do formulário). Ficam 5 s; "Muitas
/// tentativas" fica os 60 s do bloqueio, com a contagem (decisão do usuário,
/// 27/10/2026).
enum SignUpAlert { emailInUse, offline, tooManyRequests, generic }

@immutable
class SignUpState {
  const SignUpState({
    this.values = const {},
    this.touched = const {},
    this.accepted = false,
    this.submitting = false,
    this.googleLoading = false,
    this.alert,
    this.lockedFor = 0,
  });

  final Map<SignUpField, String> values;

  /// Campos que já perderam o foco: só eles mostram erro.
  final Set<SignUpField> touched;
  final bool accepted;
  final bool submitting;
  final bool googleLoading;
  final SignUpAlert? alert;

  /// Segundos de bloqueio depois de "Muitas tentativas".
  final int lockedFor;

  bool get busy => submitting || googleLoading;

  String valueOf(SignUpField field) => values[field] ?? '';

  SignUpState copyWith({
    Map<SignUpField, String>? values,
    Set<SignUpField>? touched,
    bool? accepted,
    bool? submitting,
    bool? googleLoading,
    SignUpAlert? Function()? alert,
    int? lockedFor,
  }) => SignUpState(
    values: values ?? this.values,
    touched: touched ?? this.touched,
    accepted: accepted ?? this.accepted,
    submitting: submitting ?? this.submitting,
    googleLoading: googleLoading ?? this.googleLoading,
    alert: alert == null ? this.alert : alert(),
    lockedFor: lockedFor ?? this.lockedFor,
  );
}

/// Estado da tela 03 Cadastro. O botão fica desabilitado até tudo estar
/// válido e o aceite marcado; os erros aparecem quando o campo perde o foco.
class SignUpController extends Notifier<SignUpState> {
  late final Countdown _lock;
  final _alertTimer = AlertTimer();

  @override
  SignUpState build() {
    _lock = Countdown((remaining) {
      if (!ref.mounted) return;
      state = state.copyWith(
        lockedFor: remaining,
        alert: remaining <= 0 && state.alert == SignUpAlert.tooManyRequests
            ? () => null
            : null,
      );
    });
    ref.onDispose(() {
      _lock.cancel();
      _alertTimer.cancel();
    });
    return const SignUpState();
  }

  LocalDate get _today => LocalDate.fromDateTime(ref.read(clockProvider)());

  String? _validate(SignUpField field, String value) => switch (field) {
    SignUpField.name => ProfileForm.nameError(value),
    SignUpField.birthDate => ProfileForm.birthDateError(value, _today),
    SignUpField.email => ProfileForm.emailError(value),
    SignUpField.password => ProfileForm.passwordError(value),
  };

  /// Erro visível do campo (só depois de perder o foco).
  String? errorOf(SignUpField field) => state.touched.contains(field)
      ? _validate(field, state.valueOf(field))
      : null;

  bool get canSubmit =>
      !state.busy &&
      state.lockedFor == 0 &&
      state.accepted &&
      SignUpField.values.every((f) => _validate(f, state.valueOf(f)) == null);

  /// Texto abaixo do botão desabilitado (03 Default e Erros de campo).
  String? get hint {
    if (canSubmit || state.busy || state.lockedFor > 0) return null;
    final visibleError = SignUpField.values.any((f) => errorOf(f) != null);
    if (visibleError) {
      return state.accepted
          ? 'Corrija os campos marcados.'
          : 'Corrija os campos marcados e marque o aceite.';
    }
    final anyEmpty = SignUpField.values.any(
      (f) => state.valueOf(f).trim().isEmpty,
    );
    if (anyEmpty) {
      return state.accepted
          ? 'Preencha os campos para criar a conta.'
          : 'Preencha os campos e marque o aceite para criar a conta.';
    }
    return state.accepted
        ? 'Corrija os campos marcados.'
        : 'Marque o aceite para criar a conta.';
  }

  void change(SignUpField field, String value) {
    // Além dos 5 s: "Já tem uma conta" sai ao editar o e-mail; o genérico,
    // ao editar qualquer campo.
    final alert = switch (state.alert) {
      SignUpAlert.emailInUse when field == SignUpField.email => null,
      SignUpAlert.generic => null,
      final other => other,
    };
    // Data completa (digitada ou do calendário) já mostra o erro.
    final complete = field == SignUpField.birthDate && value.length == 10;
    state = state.copyWith(
      values: {...state.values, field: value},
      touched: complete ? {...state.touched, field} : null,
      alert: () => alert,
    );
  }

  void blur(SignUpField field) {
    if (state.touched.contains(field)) return;
    state = state.copyWith(touched: {...state.touched, field});
  }

  void setAccepted(bool value) => state = state.copyWith(accepted: value);

  Future<void> submit() async {
    if (!canSubmit) return;
    final auth = ref.read(authRepositoryProvider);
    final profiles = ref.read(userProfileRepositoryProvider);
    final legal = ref.read(legalDocumentsRepositoryProvider);
    final timeZone = ref.read(deviceTimeZoneProvider);
    final today = _today;
    state = state.copyWith(submitting: true, alert: () => null);

    try {
      final profile = NewUserProfile(
        displayName: state.valueOf(SignUpField.name),
        birthDate: ProfileForm.parseBirthDate(
          state.valueOf(SignUpField.birthDate),
          today,
        )!,
        timeZone: timeZone,
        consents: await legal.currentVersions(),
        today: today,
      );
      await auth.createAccount(
        email: state.valueOf(SignUpField.email).trim(),
        password: state.valueOf(SignUpField.password),
      );
      await profiles.createProfile(auth.currentUser!.uid, profile);
      try {
        await auth.sendEmailVerification();
      } on AuthFailure {
        // A tela 05 tem "Reenviar e-mail".
      }
      // O roteador leva à tela 05 assim que a conta existe.
      if (ref.mounted) state = state.copyWith(submitting: false);
    } on AuthFailure catch (failure) {
      _fail(failure.code);
    }
  }

  /// "Continuar com o Google": sem perfil, o roteador leva à 03b.
  Future<void> signInWithGoogle() async {
    if (state.busy || state.lockedFor > 0) return;
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
    final alert = switch (code) {
      AuthFailureCode.emailAlreadyInUse => SignUpAlert.emailInUse,
      AuthFailureCode.network => SignUpAlert.offline,
      AuthFailureCode.tooManyRequests => SignUpAlert.tooManyRequests,
      _ => SignUpAlert.generic,
    };
    state = state.copyWith(
      submitting: false,
      googleLoading: false,
      alert: () => alert,
    );
    if (alert == SignUpAlert.tooManyRequests) {
      _alertTimer.cancel();
      _lock.start(tooManyRequestsLockSeconds);
      return;
    }
    _alertTimer.start(() {
      if (ref.mounted && state.alert == alert) {
        state = state.copyWith(alert: () => null);
      }
    });
  }
}

final signUpControllerProvider =
    NotifierProvider.autoDispose<SignUpController, SignUpState>(
      SignUpController.new,
    );
