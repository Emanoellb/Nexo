import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A animação da splash terminou. Até lá, o roteador mantém o usuário na
/// splash, mesmo que o login já tenha carregado. Não há espera artificial:
/// ela sai quando a animação acaba e o login carregou, o que vier por último.
final splashFinishedProvider = NotifierProvider<SplashFinished, bool>(
  SplashFinished.new,
);

class SplashFinished extends Notifier<bool> {
  @override
  bool build() => false;

  void finish() => state = true;
}
