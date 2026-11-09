import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/nexo_app.dart';
import 'app/prototype/sample_data.dart';
import 'app/startup/app_startup.dart';
import 'core/data/local_flags.dart';
import 'features/focus/application/focus_system.dart';
import 'features/focus/data/android_focus_system.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Marcas locais (ex.: primeira abertura), lidas antes do primeiro quadro:
  // a splash precisa delas para decidir se mostra as boas-vindas.
  final localFlags = await SharedPreferencesLocalFlags.create();

  // Notificação fixa e "Não perturbe" do Foco (só no Android).
  final focusSystem = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? AndroidFocusSystem()
      : null;

  // O resto da carga roda enquanto a splash anima (appStartupProvider), para
  // o primeiro quadro sair o quanto antes.
  final container = ProviderContainer(
    overrides: [
      localFlagsProvider.overrideWithValue(localFlags),
      if (focusSystem != null)
        focusSystemProvider.overrideWithValue(focusSystem),
      // Na prototipação, os repositórios são fake (sem banco) e a conta de
      // protótipo começa com dados de exemplo fictícios; contas novas
      // começam vazias. A troca pelo Firebase é feita nos providers de cada
      // feature; aí estes dados saem.
      prototypeSeedingProvider.overrideWithValue(true),
      appStartupProvider.overrideWith((ref) async {
        // O Foco desliga um "Não perturbe" que tenha ficado ligado de antes
        // (app fechado à força) antes de qualquer tela usar o foco.
        await Future.wait([_initFirebase(), ?focusSystem?.init()]);
      }),
    ],
  );
  // Começa já; a splash espera o resultado no fim da animação.
  container.read(appStartupProvider);
  // Semeia os exemplos a cada login na conta de protótipo (os dados são por
  // conta e recriados na troca de conta).
  container.listen(prototypeSampleDataProvider, (_, _) {});

  runApp(
    UncontrolledProviderScope(container: container, child: const NexoApp()),
  );
}

Future<void> _initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Sem Analytics no MVP (D2). O Crashlytics fica desligado em debug para os
  // testes não entrarem nos relatórios.
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}
