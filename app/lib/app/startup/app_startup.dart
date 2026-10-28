import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Carga inicial que roda **em paralelo com a animação da splash** (Firebase,
/// Crashlytics, dados de exemplo). O `main` troca pela carga real; a splash
/// só sai quando a animação e esta carga terminam.
///
/// Antes ela rodava antes do `runApp` e segurava a splash nativa estática
/// (medido em 27/10/2026: +0,47 s em profile e +1,76 s em debug).
final appStartupProvider = FutureProvider<void>((ref) async {});
