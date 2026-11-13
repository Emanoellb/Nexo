import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// O `flutter_local_notifications` do app, iniciado uma vez só. O plugin
/// guarda um único tratador de toque: aqui ele vira um fluxo de `payload`,
/// e cada parte (o Foco e os avisos agendados) fica com os seus.
class AndroidNotifications {
  AndroidNotifications({FlutterLocalNotificationsPlugin? plugin})
    : plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin plugin;

  /// Ícone pequeno das notificações (o símbolo do Nexo).
  static const smallIcon = 'ic_splash_symbol';

  final _taps = StreamController<String>.broadcast();
  String? _launchPayload;
  Future<void>? _ready;

  AndroidFlutterLocalNotificationsPlugin? get android => plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Prepara o plugin e guarda o `payload` do toque que abriu o app.
  Future<void> init() => _ready ??= _init();

  Future<void> _init() async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(smallIcon),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _taps.add(payload);
      },
    );
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _launchPayload = launch?.notificationResponse?.payload;
    }
  }

  /// Toques com o app aberto.
  Stream<String> get taps => _taps.stream;

  /// O `payload` do toque que abriu o app, se [accepts] for dele (lido uma
  /// vez).
  String? takeLaunchPayload(bool Function(String payload) accepts) {
    final payload = _launchPayload;
    if (payload == null || !accepts(payload)) return null;
    _launchPayload = null;
    return payload;
  }

  /// Pede a permissão de notificações (Android 13+). O sistema só pergunta
  /// enquanto a pessoa não decidiu. Devolve se as notificações estão
  /// permitidas.
  Future<bool> requestPermission() async {
    await init();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// As notificações do app estão permitidas agora.
  Future<bool> permissionGranted() async {
    await init();
    return await android?.areNotificationsEnabled() ?? false;
  }
}
