import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Canal com a `MainActivity` (Android): troca o fundo da janela nativa.
const _windowChannel = MethodChannel('nexo/window');

/// Mantém o fundo da janela do Android igual ao `Surface` do tema ATIVO.
///
/// O tema nativo (`values` / `values-night`) segue o modo do sistema. Com
/// "Claro" ou "Escuro" escolhido no app ao contrário do sistema, a janela
/// atrás do Flutter ficaria no outro tema e apareceria em redimensionamentos
/// e transições. A splash nativa, antes do 1º quadro, continua seguindo o
/// sistema (o Android abre antes de o app ler a preferência).
class WindowBackgroundSync extends StatefulWidget {
  const WindowBackgroundSync({super.key, required this.child});

  final Widget child;

  @override
  State<WindowBackgroundSync> createState() => _WindowBackgroundSyncState();
}

class _WindowBackgroundSyncState extends State<WindowBackgroundSync> {
  Color? _sent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final surface = Theme.of(context).colorScheme.surface;
    if (surface == _sent) return;
    _sent = surface;
    _send(surface);
  }

  static Future<void> _send(Color color) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _windowChannel.invokeMethod<void>(
        'setBackgroundColor',
        color.toARGB32(),
      );
    } on MissingPluginException {
      // Testes e execuções sem a MainActivity do app: nada a sincronizar.
    } on PlatformException {
      // Falhar aqui só deixa o fundo nativo no tema do sistema.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
