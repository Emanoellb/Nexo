import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/nexo_app.dart';
import 'core/data/local_flags.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  // Marcas locais (ex.: primeira abertura), lidas antes do primeiro quadro.
  final localFlags = await SharedPreferencesLocalFlags.create();

  // Na prototipação, os repositórios são fake (sem login nem banco). A troca
  // pelo Firebase é feita nos providers de cada feature.
  runApp(
    ProviderScope(
      overrides: [localFlagsProvider.overrideWithValue(localFlags)],
      child: const NexoApp(),
    ),
  );
}
