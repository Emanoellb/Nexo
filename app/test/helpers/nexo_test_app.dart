import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/theme/nexo_theme.dart';

/// Envolve [child] no tema do Nexo (claro, ou escuro com [dark]), com
/// animações desligadas (o spinner fica parado e o pumpAndSettle termina).
Widget nexoTestApp(Widget child, {double width = 390, bool dark = false}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? NexoTheme.dark() : NexoTheme.light(),
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    ),
  );
}

bool _fontsLoaded = false;

/// Carrega as fontes reais (Manrope e o pacote de ícones Lucide) a partir do
/// FontManifest. Sem isso, os testes desenham tudo com a fonte Ahem
/// (retângulos) e os goldens não mostram o componente de verdade.
Future<void> loadNexoFonts() async {
  if (_fontsLoaded) return;
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  _fontsLoaded = true;
}

/// Liga o anel de foco como se o usuário navegasse por teclado.
void useKeyboardFocusHighlight() {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
}

void resetFocusHighlight() {
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
}
