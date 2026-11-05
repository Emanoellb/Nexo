import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/nexo_theme.dart';
import '../core/theme/theme_preference.dart';
import 'router/app_router.dart';
import 'window_background.dart';

class NexoApp extends ConsumerWidget {
  const NexoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Nexo',
      debugShowCheckedModeBanner: false,
      theme: NexoTheme.light(),
      darkTheme: NexoTheme.dark(),
      themeMode: ref.watch(themePreferenceProvider),
      // MVP só em pt-BR: calendário, menus de texto e leitor de tela.
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      // Ícones da barra de status legíveis nos dois temas, em toda tela sem
      // TopAppBar (splash, entrada, topo das abas). Só os campos da barra de
      // status: os presets SystemUiOverlayStyle.dark/.light também pintam a
      // barra de navegação do Android de preto.
      builder: (context, child) {
        final light = Theme.of(context).brightness == Brightness.light;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
            statusBarBrightness: light ? Brightness.light : Brightness.dark,
          ),
          child: WindowBackgroundSync(child: child!),
        );
      },
    );
  }
}
