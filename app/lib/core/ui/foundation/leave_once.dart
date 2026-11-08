import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Sai da tela uma vez só: toques repetidos (voltar, "Salvar" e a tela
/// excluída em outro lugar) não tiram duas telas da pilha.
mixin LeaveOnce<T extends StatefulWidget> on State<T> {
  bool _leaving = false;

  /// Já está saindo (a tela não volta a perguntar nada).
  bool get leaving => _leaving;

  void leave() {
    if (_leaving) return;
    _leaving = true;
    context.pop();
  }
}
