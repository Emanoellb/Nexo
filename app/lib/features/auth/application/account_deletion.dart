import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/local_flags.dart';
import '../../focus/application/focus_controller.dart';
import 'auth_providers.dart';
import 'login_controller.dart';

/// Apaga os dados da conta no banco (planos e o que há dentro, tarefas,
/// disciplinas, objetivos, medalhas, avisos). No bloco de integração, o
/// Firestore em lotes, liberado pelo `deletionRequestedAt` (contrato §3,
/// item 6). Na prototipação os repositórios fake são por conta e somem com
/// ela, então não há o que apagar.
abstract interface class UserDataEraser {
  Future<void> eraseAll(String uid);
}

class FakeUserDataEraser implements UserDataEraser {
  const FakeUserDataEraser();

  @override
  Future<void> eraseAll(String uid) async {}
}

final userDataEraserProvider = Provider<UserDataEraser>(
  (ref) => const FakeUserDataEraser(),
);

/// A exclusão está rodando nesta abertura do app: a entrada fica em
/// "Excluindo" mesmo depois de `users/{uid}` sumir (senão iria para a 03b).
final accountDeletionRunningProvider =
    NotifierProvider<AccountDeletionRunning, bool>(AccountDeletionRunning.new);

class AccountDeletionRunning extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Excluir conta (Perfil 07 a 10; contrato: `users.deletionRequestedAt`).
class AccountDeletion {
  AccountDeletion(this._ref);

  final Ref _ref;

  /// Passo 3: grava `deletionRequestedAt` (uma vez só, não se desfaz). A
  /// entrada passa a "Excluindo" e o app vai para a tela 09, que chama
  /// [finish]. Se o app fechar no meio, o próximo login também vai.
  Future<void> request() async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    _ref.read(accountDeletionRunningProvider.notifier).set(true);
    await _ref.read(userProfileRepositoryProvider).markDeletionRequested(uid);
  }

  /// Termina a exclusão: tira o foco em andamento (e o "Não perturbe"),
  /// apaga os dados no banco, o `users/{uid}`, o que o aparelho guarda da
  /// conta e a conta do Auth. O Login abre com "Conta excluída.".
  Future<void> finish() async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    _ref.read(accountDeletionRunningProvider.notifier).set(true);
    try {
      await _ref.read(activeFocusProvider.notifier).clear();
      await _ref.read(userDataEraserProvider).eraseAll(uid);
      await _ref.read(userProfileRepositoryProvider).deleteProfile(uid);
      await _ref.read(localFlagsProvider).clearAccount(uid);
      _ref
          .read(entryNoticeProvider.notifier)
          .show(EntryNoticeKind.accountDeleted);
      await _ref.read(authRepositoryProvider).deleteCurrentUser();
    } finally {
      _ref.read(accountDeletionRunningProvider.notifier).set(false);
    }
  }
}

final accountDeletionProvider = Provider<AccountDeletion>(AccountDeletion.new);
