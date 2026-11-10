import 'package:flutter/widgets.dart';

/// Rodapé de ações de uma tela cheia (Salvar, Criar, Próximo), no
/// `bottomNavigationBar` do Scaffold:
/// - a Snackbar flutuante aparece acima dele, nunca por cima (decisão
///   travada: Snackbar embaixo, acima da barra/rodapé);
/// - com o teclado aberto, sobe junto e fica visível logo acima dele
///   (`viewInsets`); sem teclado, respeita a área segura de baixo.
class NexoScreenFooter extends StatelessWidget {
  const NexoScreenFooter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(top: false, child: child),
  );
}
