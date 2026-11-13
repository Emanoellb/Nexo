import 'dart:async';

import 'package:nexo/features/notifications/application/local_notices.dart';
import 'package:nexo/features/notifications/domain/local_notice.dart';

/// Guarda o que o app agendou e responde ao pedido de permissão como o
/// Android: [allowed] é a permissão atual, [grantOnRequest] o que a pessoa
/// escolhe no pedido.
class SpyLocalNotices implements LocalNotices {
  SpyLocalNotices({this.allowed = true, bool? grantOnRequest})
    : grantOnRequest = grantOnRequest ?? allowed;

  final scheduled = <List<LocalNotice>>[];
  var clears = 0;
  var permissionRequests = 0;
  var settingsOpened = 0;
  final tapController = StreamController<String>.broadcast();
  String? launch;
  bool allowed;
  bool grantOnRequest;

  @override
  Future<void> replaceAll(List<LocalNotice> notices) async =>
      scheduled.add(notices);

  @override
  Future<void> clear() async => clears++;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (!allowed) allowed = grantOnRequest;
    return allowed;
  }

  @override
  Future<bool> permissionGranted() async => allowed;

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Stream<String> get taps => tapController.stream;

  @override
  String? takeLaunchPayload() {
    final payload = launch;
    launch = null;
    return payload;
  }
}
