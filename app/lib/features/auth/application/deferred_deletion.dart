import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

/// Itens com exclusão pendente (tarefas, disciplinas, objetivos, tópicos): somem da tela na hora e só são apagados de
/// verdade quando a Snackbar com "Desfazer" some sem o toque (design de
/// 04/11/2026: excluir não pede confirmação). Um conjunto por conta: trocar
/// de conta descarta os pendentes.
class PendingDeletions extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(currentUidProvider);
    return const {};
  }

  void add(String id) => state = {...state, id};

  void remove(String id) => state = {...state}..remove(id);
}

/// O que a tela guarda de uma exclusão adiada: o item e a conta em que ela
/// começou.
typedef DeletionReceipt = ({String id, String? uid});

/// Exclusão com "Desfazer": [begin] esconde, [undo] devolve e [finish]
/// apaga. Presa à conta: se ela mudar antes do fim (sair, trocar de conta),
/// nada é apagado nem devolvido na conta nova.
class DeferredDeletion {
  DeferredDeletion(this._ref, this._pending, this._delete);

  final Ref _ref;
  final NotifierProvider<PendingDeletions, Set<String>> _pending;
  final Future<void> Function(String id) _delete;

  bool _sameAccount(DeletionReceipt receipt) =>
      _ref.read(currentUidProvider) == receipt.uid;

  DeletionReceipt begin(String id) {
    _ref.read(_pending.notifier).add(id);
    return (id: id, uid: _ref.read(currentUidProvider));
  }

  void undo(DeletionReceipt receipt) {
    if (_sameAccount(receipt)) _ref.read(_pending.notifier).remove(receipt.id);
  }

  Future<void> finish(DeletionReceipt receipt) async {
    if (!_sameAccount(receipt)) return;
    await _delete(receipt.id);
    if (_sameAccount(receipt)) _ref.read(_pending.notifier).remove(receipt.id);
  }
}
