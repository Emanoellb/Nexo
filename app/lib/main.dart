import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/nexo_app.dart';
import 'app/startup/app_startup.dart';
import 'core/data/android_notifications.dart';
import 'core/data/device_actions.dart';
import 'core/data/firebase_ready.dart';
import 'core/data/local_flags.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/focus/application/focus_system.dart';
import 'features/focus/data/android_focus_system.dart';
import 'features/notifications/application/local_notices.dart';
import 'features/notifications/application/notifications_providers.dart';
import 'features/notifications/data/android_local_notices.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Marcas locais (ex.: primeira abertura), lidas antes do primeiro quadro:
  // a splash precisa delas para decidir se mostra as boas-vindas.
  final localFlags = await SharedPreferencesLocalFlags.create();

  // Notificações (só no Android): um plugin para a notificação fixa e o
  // "Não perturbe" do Foco e para os avisos agendados.
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final notifications = android ? AndroidNotifications() : null;
  final focusSystem = notifications == null
      ? null
      : AndroidFocusSystem(notifications);
  const device = AndroidDeviceActions();

  // Fuso do aparelho para o cadastro (users.timeZone), lido uma vez.
  final timeZone = normalizeTimeZone(android ? await device.timeZone() : null);

  // Firebase começa já e roda durante a splash. Os repositórios (Auth e
  // Firestore, nos providers de cada feature) esperam por ele.
  final firebaseReady = _initFirebase();

  // O resto da carga roda enquanto a splash anima (appStartupProvider), para
  // o primeiro quadro sair o quanto antes.
  final container = ProviderContainer(
    overrides: [
      localFlagsProvider.overrideWithValue(localFlags),
      if (focusSystem != null)
        focusSystemProvider.overrideWithValue(focusSystem),
      if (notifications != null)
        localNoticesProvider.overrideWithValue(
          AndroidLocalNotices(notifications),
        ),
      if (android) deviceActionsProvider.overrideWithValue(device),
      deviceTimeZoneProvider.overrideWithValue(timeZone),
      firebaseReadyProvider.overrideWithValue(firebaseReady),
      appStartupProvider.overrideWith((ref) async {
        // O Foco desliga um "Não perturbe" que tenha ficado ligado de antes
        // (app fechado à força) antes de qualquer tela usar o foco.
        await Future.wait([firebaseReady, ?focusSystem?.init()]);
      }),
    ],
  );
  // Começa já; a splash espera o resultado no fim da animação.
  container.read(appStartupProvider);
  // Avisos agendados iguais aos dados (refeitos a cada mudança).
  container.listen(localNoticesSyncProvider, (_, _) {});
  // Histórico do sino: grava os avisos que já aconteceram.
  container.listen(notificationHistorySyncProvider, (_, _) {});

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
