import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Se o aparelho tem alguma rede (Wi-Fi, dados móveis…). É o sinal de
/// "sem conexão" do Início (decisão do usuário, 05/11/2026: pacote
/// `connectivity_plus`). Não garante que a internet responda: só que há
/// rede ligada.
abstract interface class ConnectivitySource {
  Stream<bool> watchOnline();
}

/// Pelo `connectivity_plus`. Sem o plugin (testes, outras plataformas),
/// considera online: o alerta nunca aparece por engano.
class PluginConnectivitySource implements ConnectivitySource {
  PluginConnectivitySource([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Stream<bool> watchOnline() async* {
    try {
      yield _online(await _connectivity.checkConnectivity());
    } on MissingPluginException {
      yield true;
      return;
    } on PlatformException {
      yield true;
      return;
    }
    yield* _connectivity.onConnectivityChanged.map(_online);
  }
}

final connectivitySourceProvider = Provider<ConnectivitySource>(
  (ref) => PluginConnectivitySource(),
);

/// `true` com rede; começa como online até a primeira leitura.
final onlineProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivitySourceProvider).watchOnline(),
);
