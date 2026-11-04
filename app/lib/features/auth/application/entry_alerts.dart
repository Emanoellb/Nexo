import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_failure.dart';
import '../domain/auth_failure.dart';
import 'auth_messages.dart';

/// Alertas das telas de entrada num lugar só (decisões do usuário de
/// 27/10/2026): cada alerta fica [alertDuration] na tela; "Muitas
/// tentativas" fica os [tooManyRequestsLockSeconds] do bloqueio, com a
/// contagem no estado, e sai quando o bloqueio acaba.
///
/// Quem usa implementa [alertOf] e [withAlert] (e [withLock], se a tela
/// tiver bloqueio) e chama [disposeAlerts] no `ref.onDispose`.
mixin EntryAlerts<S, A extends Object> on Notifier<S> {
  final _alertTimer = AlertTimer();
  Countdown? _lock;
  A? _lockAlert;
  var _lockedFor = 0;

  /// Há bloqueio de "Muitas tentativas" em andamento.
  bool get isLocked => _lockedFor > 0;

  /// O alerta que deve ficar na tela sem outro aviso: o do bloqueio, se ele
  /// estiver ativo; senão, nenhum.
  A? get restingAlert => isLocked ? _lockAlert : null;

  A? alertOf(S state);
  S withAlert(S state, A? alert);

  /// Segundos de bloqueio que faltam, gravados no estado.
  S withLock(S state, int seconds) => state;

  void disposeAlerts() {
    _alertTimer.cancel();
    _lock?.cancel();
  }

  /// Mostra [alert] e o tira depois de [alertDuration], se ainda for o atual.
  /// Durante um bloqueio, o "Muitas tentativas" volta no lugar dele.
  void showAlert(A alert) {
    state = withAlert(state, alert);
    _alertTimer.start(() {
      if (ref.mounted && alertOf(state) == alert) {
        state = withAlert(state, restingAlert);
      }
    });
  }

  /// "Muitas tentativas": mostra [alert] e bloqueia; no fim, o alerta sai.
  void startLock(A alert) {
    _alertTimer.cancel();
    _lockAlert = alert;
    state = withAlert(state, alert);
    _lock ??= Countdown((remaining) {
      if (!ref.mounted) return;
      _lockedFor = remaining;
      var next = withLock(state, remaining);
      if (remaining <= 0 && alertOf(next) == _lockAlert) {
        next = withAlert(next, null);
      }
      state = next;
    });
    _lock!.start(tooManyRequestsLockSeconds);
  }
}

/// Código de auth de qualquer falha de um envio: [AuthFailure] e
/// [DataFailure] viram o código equivalente; o resto, `unknown`, registrado
/// no console para não sumir em silêncio.
AuthFailureCode failureCodeOf(Object error, StackTrace stack) {
  if (error is AuthFailure) return error.code;
  if (error is DataFailure) {
    return error.code == DataFailureCode.network
        ? AuthFailureCode.network
        : AuthFailureCode.unknown;
  }
  FlutterError.reportError(
    FlutterErrorDetails(exception: error, stack: stack, library: 'nexo auth'),
  );
  return AuthFailureCode.unknown;
}
