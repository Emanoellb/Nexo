import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ações do aparelho usadas pelo Perfil (09/11/2026): abrir o app de
/// e-mail, o discador (só preenche o número) e ler a versão do app. No
/// Android, pelo canal `nexo/device` (MainActivity.kt), sem pacote, sem
/// permissão e sem `<queries>` no manifesto.
abstract interface class DeviceActions {
  /// Abre o app de e-mail com [address], [subject] e [body] já preenchidos
  /// (a pessoa revisa e envia). `false` se não houver app de e-mail.
  Future<bool> openEmail(String address, {String? subject, String? body});

  /// `false` se não houver discador (ex.: tablet sem telefone).
  Future<bool> openDialer(String number);

  /// "1.0.0" (o `versionName` do Android). `null` se não der para ler.
  Future<String?> appVersion();

  /// Fuso IANA do aparelho ("America/Sao_Paulo"). `null` se não der para ler.
  Future<String?> timeZone();
}

class AndroidDeviceActions implements DeviceActions {
  const AndroidDeviceActions();

  static const _channel = MethodChannel('nexo/device');

  @override
  Future<bool> openEmail(
    String address, {
    String? subject,
    String? body,
  }) async =>
      await _channel.invokeMethod<bool>('openEmail', {
        'address': address,
        'subject': ?subject,
        'body': ?body,
      }) ??
      false;

  @override
  Future<bool> openDialer(String number) async =>
      await _channel.invokeMethod<bool>('openDialer', number) ?? false;

  @override
  Future<String?> appVersion() => _channel.invokeMethod<String>('appVersion');

  @override
  Future<String?> timeZone() => _channel.invokeMethod<String>('timeZone');
}

/// Sem parte nativa (testes e fora do Android): nada abre.
class NoopDeviceActions implements DeviceActions {
  const NoopDeviceActions();

  @override
  Future<bool> openEmail(
    String address, {
    String? subject,
    String? body,
  }) async => false;

  @override
  Future<bool> openDialer(String number) async => false;

  @override
  Future<String?> appVersion() async => null;

  @override
  Future<String?> timeZone() async => null;
}

/// Sobrescrito no `main.dart` pelo [AndroidDeviceActions] no Android.
final deviceActionsProvider = Provider<DeviceActions>(
  (ref) => const NoopDeviceActions(),
);

/// A versão do app ("Nexo 1.0.0" no fim do Perfil).
final appVersionProvider = FutureProvider<String?>(
  (ref) => ref.watch(deviceActionsProvider).appVersion(),
);
