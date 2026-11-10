import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_user.dart';
import '../../focus/application/focus_controller.dart';
import '../../focus/application/focus_system.dart';

/// Suporte do Perfil (decisão do usuário, 07/11/2026). O e-mail é o canal
/// de contato da Política de Privacidade. O telefone é **fictício e
/// provisório**: o número real entra antes de publicar.
abstract final class NexoSupport {
  static const email = 'emanoelbarbosa.dev@gmail.com';
  static const phoneText = '(11) 0000-0000 · seg a sex, 9h às 18h';
  static const phoneDial = '1100000000';
}

/// O que o Perfil grava em `users/{uid}`.
class ProfileActions {
  ProfileActions(this._ref);

  final Ref _ref;

  String? get _uid => _ref.read(currentUidProvider);

  /// Editar perfil: o nome (1 a 80, sem espaços nas pontas).
  Future<void> rename(String name) async {
    final uid = _uid;
    if (uid == null) return;
    await _ref
        .read(userProfileRepositoryProvider)
        .updateDisplayName(uid, name.trim());
  }

  /// Limite de tarefas por dia, de 1 a 20.
  Future<void> setOverloadThreshold(int value) async {
    final uid = _uid;
    if (uid == null) return;
    await _ref
        .read(userProfileRepositoryProvider)
        .setOverloadThreshold(
          uid,
          value.clamp(
            UserProfile.minOverloadThreshold,
            UserProfile.maxOverloadThreshold,
          ),
        );
  }

  /// Aviso da manhã: liga, desliga ou muda o horário ("HH:mm"). O
  /// agendamento da notificação entra com a frente dos avisos.
  Future<void> setMorningSummary(MorningSummary summary) async {
    final uid = _uid;
    if (uid == null) return;
    await _ref
        .read(userProfileRepositoryProvider)
        .setMorningSummary(uid, summary);
  }

  /// Sair: o foco em andamento fica guardado para quando a pessoa voltar,
  /// mas a notificação fixa sai e o "Não perturbe" volta ao estado de antes.
  Future<void> signOut() async {
    final focus = _ref.read(activeFocusProvider);
    final system = _ref.read(focusSystemProvider);
    if (focus != null) {
      if (focus.dnd) await system.setDnd(on: false);
      await system.clearOngoing();
    }
    await _ref.read(authRepositoryProvider).signOut();
  }
}

final profileActionsProvider = Provider<ProfileActions>(ProfileActions.new);
