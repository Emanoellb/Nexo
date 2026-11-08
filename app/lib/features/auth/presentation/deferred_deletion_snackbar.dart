import 'package:flutter/widgets.dart';

import '../../../core/ui/ui.dart';
import '../application/deferred_deletion.dart';

/// A Snackbar com "Desfazer" de uma exclusão adiada.
extension DeferredDeletionSnackbar on DeferredDeletion {
  /// Esconde [id] na hora e mostra [message] com "Desfazer": o toque
  /// devolve; a Snackbar sumir de outro jeito apaga de vez.
  void withUndo(BuildContext context, String id, {required String message}) {
    final receipt = begin(id);
    showUndoSnackbar(
      context,
      message: message,
      onUndo: () => undo(receipt),
      onCommit: () => finish(receipt),
    );
  }
}
