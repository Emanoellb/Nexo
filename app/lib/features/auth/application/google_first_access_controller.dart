import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../../../core/domain/local_date.dart';
import '../../legal/data/legal_documents_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_rules.dart';
import '../domain/auth_user.dart';
import 'auth_providers.dart';
import 'entry_alerts.dart';
import 'login_controller.dart';
import 'profile_form.dart';

enum GoogleFirstAccessField { name, birthDate }

enum GoogleFirstAccessAlert { offline, generic }

@immutable
class GoogleFirstAccessState {
  const GoogleFirstAccessState({
    required this.name,
    this.birthDate = '',
    this.touched = const {},
    this.accepted = false,
    this.submitting = false,
    this.leaving = false,
    this.alert,
  });

  final String name;
  final String birthDate;
  final Set<GoogleFirstAccessField> touched;
  final bool accepted;
  final bool submitting;

  /// Voltar ou recusa da idade em andamento.
  final bool leaving;
  final GoogleFirstAccessAlert? alert;

  GoogleFirstAccessState copyWith({
    String? name,
    String? birthDate,
    Set<GoogleFirstAccessField>? touched,
    bool? accepted,
    bool? submitting,
    bool? leaving,
    GoogleFirstAccessAlert? Function()? alert,
  }) => GoogleFirstAccessState(
    name: name ?? this.name,
    birthDate: birthDate ?? this.birthDate,
    touched: touched ?? this.touched,
    accepted: accepted ?? this.accepted,
    submitting: submitting ?? this.submitting,
    leaving: leaving ?? this.leaving,
    alert: alert == null ? this.alert : alert(),
  );
}

/// Estado da tela 03b: data de nascimento (16+) e aceite no primeiro login
/// Google. A conta do Auth já existe; quem tem menos de 16 anos tem a conta
/// apagada ao tocar em Continuar (firestore-rules.md §7, item 4).
class GoogleFirstAccessController extends Notifier<GoogleFirstAccessState>
    with EntryAlerts<GoogleFirstAccessState, GoogleFirstAccessAlert> {
  @override
  GoogleFirstAccessState build() {
    ref.onDispose(disposeAlerts);
    return GoogleFirstAccessState(
      name: ref.read(authRepositoryProvider).currentUser?.displayName ?? '',
    );
  }

  @override
  GoogleFirstAccessAlert? alertOf(GoogleFirstAccessState state) => state.alert;

  @override
  GoogleFirstAccessState withAlert(
    GoogleFirstAccessState state,
    GoogleFirstAccessAlert? alert,
  ) => state.copyWith(alert: () => alert);

  /// Voltar e cancelar ficam bloqueados enquanto o perfil é gravado ou a
  /// conta é apagada (achado [1] da revisão, 04/11/2026): apagar a conta no
  /// meio da gravação deixaria `users/{uid}` órfão, com dado pessoal que as
  /// regras não deixam apagar.
  bool get canLeave => !state.submitting && !state.leaving;

  LocalDate get _today => LocalDate.fromDateTime(ref.read(clockProvider)());

  String? _validate(GoogleFirstAccessField field) => switch (field) {
    GoogleFirstAccessField.name => ProfileForm.nameError(state.name),
    GoogleFirstAccessField.birthDate => ProfileForm.birthDateError(
      state.birthDate,
      _today,
    ),
  };

  String? errorOf(GoogleFirstAccessField field) =>
      state.touched.contains(field) ? _validate(field) : null;

  /// Continuar habilita com nome, data completa e aceite, qualquer que seja a
  /// idade: a recusa da idade acontece no toque (decisão de 27/10/2026).
  bool get canSubmit =>
      !state.submitting &&
      !state.leaving &&
      state.accepted &&
      ProfileForm.nameError(state.name) == null &&
      ProfileForm.parseBirthDate(state.birthDate, _today) != null;

  String? get hint {
    if (canSubmit || state.submitting || state.leaving) return null;
    if (GoogleFirstAccessField.values.any((f) => errorOf(f) != null)) {
      return state.accepted
          ? 'Corrija os campos marcados.'
          : 'Corrija os campos marcados e marque o aceite.';
    }
    return 'Informe sua data de nascimento e marque o aceite para continuar.';
  }

  /// Editar tira o erro genérico; "sem conexão" sai na nova tentativa.
  GoogleFirstAccessAlert? get _alertAfterEdit =>
      state.alert == GoogleFirstAccessAlert.generic ? null : state.alert;

  void changeName(String value) =>
      state = state.copyWith(name: value, alert: () => _alertAfterEdit);

  void changeBirthDate(String value) => state = state.copyWith(
    birthDate: value,
    alert: () => _alertAfterEdit,
    // Data completa (digitada ou do calendário) já mostra o erro.
    touched: value.length == 10
        ? {...state.touched, GoogleFirstAccessField.birthDate}
        : null,
  );

  void blur(GoogleFirstAccessField field) {
    if (state.touched.contains(field)) return;
    state = state.copyWith(touched: {...state.touched, field});
  }

  void setAccepted(bool value) => state = state.copyWith(accepted: value);

  Future<void> submit() async {
    if (!canSubmit) return;
    final today = _today;
    final birthDate = ProfileForm.parseBirthDate(state.birthDate, today)!;
    if (!AuthRules.isOldEnough(birthDate, today)) {
      ref.read(entryNoticeProvider.notifier).show(EntryNoticeKind.underage);
      await _deleteAccount();
      return;
    }

    final auth = ref.read(authRepositoryProvider);
    final profiles = ref.read(userProfileRepositoryProvider);
    final legal = ref.read(legalDocumentsRepositoryProvider);
    final timeZone = ref.read(deviceTimeZoneProvider);
    final name = state.name;
    state = state.copyWith(submitting: true, alert: () => null);
    try {
      final profile = NewUserProfile(
        displayName: name,
        birthDate: birthDate,
        timeZone: timeZone,
        consents: await legal.currentVersions(),
        today: today,
      );
      await profiles.createProfile(auth.currentUser!.uid, profile);
      // O roteador segue para o tutorial assim que o perfil existe.
    } catch (error, stack) {
      final code = failureCodeOf(error, stack);
      if (!ref.mounted) return;
      state = state.copyWith(submitting: false);
      showAlert(
        code == AuthFailureCode.network
            ? GoogleFirstAccessAlert.offline
            : GoogleFirstAccessAlert.generic,
      );
    }
  }

  /// Voltar: sem perfil, a conta do Auth não serve para nada. Ignorado
  /// enquanto o perfil é gravado ([canLeave]).
  Future<void> cancel() async {
    if (!canLeave) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    final auth = ref.read(authRepositoryProvider);
    state = state.copyWith(leaving: true, alert: () => null);
    try {
      await auth.deleteCurrentUser();
    } catch (error, stack) {
      // Sem conseguir apagar, ao menos encerra a sessão.
      failureCodeOf(error, stack);
      await auth.signOut();
    }
  }
}

final googleFirstAccessControllerProvider =
    NotifierProvider.autoDispose<
      GoogleFirstAccessController,
      GoogleFirstAccessState
    >(GoogleFirstAccessController.new);
