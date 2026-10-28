import 'dart:async';

/// Textos de erro de campo do fluxo de entrada, iguais aos do nexo.app.pen e
/// das specs (firebase-setup.md §6, auth-redefinicao-senha.md §7).
abstract final class AuthMessages {
  static const emailEmpty = 'Informe seu e-mail.';
  static const emailInvalid = 'Confira o e-mail, ex.: nome@email.com.';
  static const passwordEmptyLogin = 'Informe sua senha.';
  static const passwordEmptySignUp = 'Crie uma senha.';
  static const passwordHelper =
      'Mínimo de 8 caracteres, com letra maiúscula, letra minúscula, número '
      'e caractere especial.';
  static const passwordInvalid =
      'Use pelo menos 8 caracteres, com letra maiúscula, letra minúscula, '
      'número e caractere especial.';
  static const nameEmpty = 'Informe como quer ser chamado.';
  static const nameTooLong = 'Use até 80 caracteres.';
  static const birthDateEmpty = 'Informe sua data de nascimento.';
  static const birthDateInvalid = 'Confira a data, ex.: 21/03/2004.';
  static const underage = 'Você precisa ter 16 anos ou mais para usar o Nexo.';

  // Tela 04 (spec auth-redefinicao-senha.md §7).
  static const resetEmailEmpty = 'Informe o e-mail da sua conta.';
  static const resetEmailInvalid =
      'Confira o e-mail digitado. Ele parece incompleto.';
}

/// Contagem regressiva em segundos ("Reenviar em 0:45").
class Countdown {
  Countdown(this.onTick);

  final void Function(int remaining) onTick;
  Timer? _timer;

  void start(int seconds) {
    _timer?.cancel();
    var remaining = seconds;
    onTick(remaining);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      onTick(remaining);
      if (remaining <= 0) timer.cancel();
    });
  }

  void cancel() => _timer?.cancel();
}

/// `0:45`.
String formatCountdown(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// Espera para reenviar e-mails (tela 04 e 05).
const resendCooldownSeconds = 45;

/// Bloqueio do botão depois de "Muitas tentativas". O alerta fica na tela
/// o mesmo tempo, com a contagem.
const tooManyRequestsLockSeconds = 60;

/// Tempo na tela dos demais alertas das telas de entrada (decisão do
/// usuário, 27/10/2026).
const alertDuration = Duration(seconds: 5);

/// Tira um alerta depois de um tempo, se ele ainda for o mesmo.
class AlertTimer {
  Timer? _timer;

  void start(void Function() onDone, {Duration duration = alertDuration}) {
    _timer?.cancel();
    _timer = Timer(duration, onDone);
  }

  void cancel() => _timer?.cancel();
}
