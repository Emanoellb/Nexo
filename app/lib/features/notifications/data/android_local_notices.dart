import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/data/android_notifications.dart';
import '../application/local_notices.dart';
import '../domain/local_notice.dart';

/// Avisos agendados no Android pelo `flutter_local_notifications`
/// (Etapa 5, aprovado em 12/11/2026):
/// - hora inexata (`inexactAllowWhileIdle`), sem permissão de alarme exato.
///   O Android pode atrasar alguns minutos, mais com a economia de bateria;
/// - a hora vai em UTC (calculada no fuso do aparelho), sem a base de fusos
///   do pacote `timezone` no APK;
/// - os avisos voltam depois de reiniciar o aparelho
///   (`RECEIVE_BOOT_COMPLETED` e os receivers do plugin no manifesto);
/// - canais "Resumo do dia", "Planos" e "Tarefas" (o "Foco" é da
///   notificação fixa).
class AndroidLocalNotices implements LocalNotices {
  AndroidLocalNotices(this._notifications);

  final AndroidNotifications _notifications;

  /// Canal `nexo/device` (MainActivity.kt): abre as configurações.
  static const _device = MethodChannel('nexo/device');

  /// Payload da notificação fixa do Foco (fica com o Foco).
  static const _focusPayload = 'focus';

  /// Ids dos avisos agendados: a partir daqui (o Foco usa 1001).
  static const _firstId = 2000;

  static const _channels = {
    NoticeChannel.daySummary: AndroidNotificationChannel(
      'day_summary',
      'Resumo do dia',
      description: 'O aviso da manhã, com os planos e as entregas do dia.',
    ),
    NoticeChannel.plans: AndroidNotificationChannel(
      'plans',
      'Planos',
      description:
          'Antes do horário do plano, a meta do dia às 21h e o fim do plano.',
    ),
    NoticeChannel.tasks: AndroidNotificationChannel(
      'tasks',
      'Tarefas',
      description: 'Os avisos antes do prazo de entrega.',
    ),
  };

  Future<void>? _channelsReady;

  Future<void> _ready() async {
    await _notifications.init();
    await (_channelsReady ??= Future.wait([
      for (final channel in _channels.values)
        ?_notifications.android?.createNotificationChannel(channel),
    ]));
  }

  @override
  Future<void> replaceAll(List<LocalNotice> notices) async {
    await _ready();
    final plugin = _notifications.plugin;
    await plugin.cancelAllPendingNotifications();
    for (final (i, notice) in notices.indexed) {
      final channel = _channels[notice.channel]!;
      await plugin.zonedSchedule(
        id: _firstId + i,
        scheduledDate: tz.TZDateTime.from(notice.at.toUtc(), tz.UTC),
        title: notice.title,
        body: notice.body,
        payload: notice.payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: AndroidNotifications.smallIcon,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
      );
    }
  }

  @override
  Future<void> clear() async {
    await _notifications.init();
    await _notifications.plugin.cancelAllPendingNotifications();
  }

  @override
  Future<bool> requestPermission() => _notifications.requestPermission();

  @override
  Future<bool> permissionGranted() => _notifications.permissionGranted();

  @override
  Future<void> openSettings() =>
      _device.invokeMethod<bool>('openNotificationSettings');

  @override
  Stream<String> get taps =>
      _notifications.taps.where((payload) => payload != _focusPayload);

  @override
  String? takeLaunchPayload() =>
      _notifications.takeLaunchPayload((p) => p != _focusPayload);
}
