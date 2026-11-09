import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/active_focus.dart';

/// O que o foco pede ao sistema (aprovado em 09/11/2026): o "Não perturbe"
/// (Android, ACCESS_NOTIFICATION_POLICY) e a notificação fixa do cronômetro
/// (telas 09 e 15, POST_NOTIFICATIONS, sem foreground service). No Android
/// é o `AndroidFocusSystem`; fora dele (iPhone, testes), [NoopFocusSystem]:
/// nada acontece e o interruptor do "Não perturbe" fica escondido.
abstract interface class FocusSystem {
  /// O aparelho tem "Não perturbe" que o app consegue ligar.
  bool get supportsDnd;

  /// O "Não perturbe" foi ligado pelo Nexo desde que o app abriu. Um foco
  /// guardado com ele ligado, sem isto, vem de antes de o app fechar: o
  /// modo já foi desligado na abertura.
  bool get dndOnSinceLaunch;

  /// O acesso ao "Não perturbe" já foi dado nas configurações do sistema.
  Future<bool> dndAccessGranted();

  /// Abre a tela do sistema para dar o acesso (uma vez só) e espera a volta
  /// ao app. Devolve se o acesso foi dado.
  Future<bool> openDndSettings();

  /// Liga ou desliga o silêncio. Ao desligar, o aparelho volta ao estado
  /// de antes do foco. Devolve se ligou (ou desligou).
  Future<bool> setDnd({required bool on});

  /// Pede a permissão de notificações (Android 13+), no primeiro foco. O
  /// sistema só pergunta enquanto a pessoa não decidiu.
  Future<void> requestNotificationPermission();

  /// Mostra ou atualiza a notificação fixa do foco (sem botões). [detail]:
  /// o plano e os tópicos.
  Future<void> showOngoing(ActiveFocus focus, {required String detail});

  /// Tira a notificação fixa.
  Future<void> clearOngoing();

  /// Toques na notificação com o app aberto: abrem o foco.
  Stream<void> get openFocusRequests;

  /// O app abriu pelo toque na notificação (lido uma vez).
  bool takeLaunchFromNotification();
}

/// Sem parte nativa (iPhone e testes): nada acontece.
class NoopFocusSystem implements FocusSystem {
  const NoopFocusSystem();

  @override
  bool get supportsDnd => false;

  @override
  bool get dndOnSinceLaunch => false;

  @override
  Future<bool> dndAccessGranted() async => false;

  @override
  Future<bool> openDndSettings() async => false;

  @override
  Future<bool> setDnd({required bool on}) async => false;

  @override
  Future<void> requestNotificationPermission() async {}

  @override
  Future<void> showOngoing(ActiveFocus focus, {required String detail}) async {}

  @override
  Future<void> clearOngoing() async {}

  @override
  Stream<void> get openFocusRequests => const Stream.empty();

  @override
  bool takeLaunchFromNotification() => false;
}

/// Sobrescrito no `main.dart` pelo `AndroidFocusSystem` no Android.
final focusSystemProvider = Provider<FocusSystem>(
  (ref) => const NoopFocusSystem(),
);
