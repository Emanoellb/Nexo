import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/ui/nexo/nexo_focus_timer.dart';
import '../application/focus_system.dart';
import '../domain/active_focus.dart';

/// Partes nativas do Foco no Android (aprovadas em 09/11/2026):
/// - notificação fixa do cronômetro pelo `flutter_local_notifications`,
///   canal "Foco", sem botões e sem foreground service. Rodando, o próprio
///   sistema conta o tempo (`usesChronometer`); pausada, mostra o tempo
///   parado. Tocar abre o foco;
/// - "Não perturbe" pelo canal `nexo/focus` (MainActivity.kt), sem pacote
///   de terceiros. Se o app fechar com ele ligado, [init] o desliga na
///   próxima abertura.
class AndroidFocusSystem implements FocusSystem {
  AndroidFocusSystem({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static const _channel = MethodChannel('nexo/focus');
  static const _notificationId = 1001;
  static const _payload = 'focus';

  static const _androidChannel = AndroidNotificationChannel(
    'focus',
    'Foco',
    description: 'O tempo do foco em andamento.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );

  final _openRequests = StreamController<void>.broadcast();
  bool _launchedFromNotification = false;
  bool _dndOn = false;
  Future<void>? _ready;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Prepara as notificações, vê se o app abriu pelo toque e desliga o
  /// "Não perturbe" que tenha ficado ligado de antes (app fechado à força).
  Future<void> init() => _ready ??= _init();

  Future<void> _init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_splash_symbol'),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == _payload) _openRequests.add(null);
      },
    );
    await _android?.createNotificationChannel(_androidChannel);
    final launch = await _plugin.getNotificationAppLaunchDetails();
    _launchedFromNotification =
        (launch?.didNotificationLaunchApp ?? false) &&
        launch?.notificationResponse?.payload == _payload;
    await _channel.invokeMethod<bool>('restoreDnd');
  }

  @override
  bool get supportsDnd => true;

  @override
  bool get dndOnSinceLaunch => _dndOn;

  @override
  Future<bool> dndAccessGranted() async =>
      await _channel.invokeMethod<bool>('dndAccessGranted') ?? false;

  @override
  Future<bool> openDndSettings() async {
    final returned = Completer<void>();
    final listener = AppLifecycleListener(
      onResume: () {
        if (!returned.isCompleted) returned.complete();
      },
    );
    try {
      final opened =
          await _channel.invokeMethod<bool>('openDndSettings') ?? false;
      if (!opened) return false;
      await returned.future;
      return await dndAccessGranted();
    } finally {
      listener.dispose();
    }
  }

  @override
  Future<bool> setDnd({required bool on}) async {
    final done = await _channel.invokeMethod<bool>('setDnd', on) ?? false;
    if (on) {
      _dndOn = done;
    } else {
      _dndOn = false;
    }
    return done;
  }

  @override
  Future<void> requestNotificationPermission() async {
    await init();
    await _android?.requestNotificationsPermission();
  }

  @override
  Future<void> showOngoing(ActiveFocus focus, {required String detail}) async {
    await init();
    final now = DateTime.now();
    final paused = focus.isPaused;
    final elapsed = focus.elapsed(now);
    await _plugin.show(
      id: _notificationId,
      title: paused ? 'Pausado · ${formatClock(elapsed)}' : 'Foco em andamento',
      body: detail,
      payload: _payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.low,
          priority: Priority.low,
          icon: 'ic_splash_symbol',
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          silent: true,
          category: AndroidNotificationCategory.stopwatch,
          visibility: NotificationVisibility.public,
          // Rodando: o sistema conta a partir do início descontadas as
          // pausas. Pausada: o tempo parado vai no título.
          usesChronometer: !paused,
          showWhen: !paused,
          when: paused ? null : now.subtract(elapsed).millisecondsSinceEpoch,
        ),
      ),
    );
  }

  @override
  Future<void> clearOngoing() async {
    await init();
    await _plugin.cancel(id: _notificationId);
  }

  @override
  Stream<void> get openFocusRequests => _openRequests.stream;

  @override
  bool takeLaunchFromNotification() {
    final launched = _launchedFromNotification;
    _launchedFromNotification = false;
    return launched;
  }
}
