import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../../auth/application/auth_providers.dart';
import '../../plans/application/plan_today.dart';
import '../../plans/application/plans_providers.dart';
import '../../plans/domain/plan.dart';
import '../../plans/domain/plan_day_result.dart';
import '../../tasks/application/tasks_providers.dart';
import '../domain/local_notice.dart';

/// Avisos agendados no aparelho (notificações locais, sem servidor). No
/// Android, `AndroidLocalNotices`; fora dele (iPhone, testes),
/// [NoLocalNotices].
abstract interface class LocalNotices {
  /// Troca todos os avisos agendados por [notices].
  Future<void> replaceAll(List<LocalNotice> notices);

  /// Tira todos os avisos agendados (sem login).
  Future<void> clear();

  /// Pede a permissão de notificações (Android 13+). Devolve se elas estão
  /// permitidas depois do pedido.
  Future<bool> requestPermission();

  /// As notificações estão permitidas agora (sem pedir).
  Future<bool> permissionGranted();

  /// Abre as configurações de notificação do app (depois de duas recusas o
  /// Android não mostra mais o pedido).
  Future<void> openSettings();

  /// Toques nos avisos com o app aberto (o `payload`, ver [NoticeTarget]).
  Stream<String> get taps;

  /// O aviso que abriu o app, se houver (lido uma vez).
  String? takeLaunchPayload();
}

/// Sem notificações locais (iPhone e testes): nada acontece.
class NoLocalNotices implements LocalNotices {
  const NoLocalNotices();

  @override
  Future<void> replaceAll(List<LocalNotice> notices) async {}

  @override
  Future<void> clear() async {}

  /// Sem notificações do sistema para pedir: vale como permitido.
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> permissionGranted() async => true;

  @override
  Future<void> openSettings() async {}

  @override
  Stream<String> get taps => const Stream.empty();

  @override
  String? takeLaunchPayload() => null;
}

/// O `main` troca pelo do Android.
final localNoticesProvider = Provider<LocalNotices>(
  (ref) => const NoLocalNotices(),
);

/// As notificações estão permitidas. O Aviso da manhã só vale com elas
/// (decisão do usuário, 12/11/2026): sem permissão, aparece e fica
/// desligado. Relido ao voltar ao app (ex.: das configurações).
final notificationsAllowedProvider =
    AsyncNotifierProvider<NotificationsAllowed, bool>(NotificationsAllowed.new);

class NotificationsAllowed extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(localNoticesProvider).permissionGranted();

  Future<bool>? _requesting;

  /// Um pedido está aberto (a janela do Android pausa o app e o volta).
  bool get requesting => _requesting != null;

  /// Pede a permissão e guarda o resultado. Um pedido de cada vez. O
  /// Android mostra o pedido até a segunda recusa; depois, só pelas
  /// configurações.
  Future<bool> request() => _requesting ??= _request();

  Future<bool> _request() async {
    try {
      final granted = await ref.read(localNoticesProvider).requestPermission();
      state = AsyncData(granted);
      return granted;
    } finally {
      _requesting = null;
    }
  }

  /// Relê sem pedir.
  Future<void> refresh() async {
    state = AsyncData(await ref.read(localNoticesProvider).permissionGranted());
  }
}

/// Espera antes de reagendar: junta as mudanças seguidas (ex.: a sessão e
/// os pontos) num agendamento só.
const noticesSyncDelay = Duration(seconds: 1);

/// Mantém os avisos agendados iguais aos dados: refaz ao abrir o app e a
/// cada mudança no perfil, nos planos (versões e dias) e nas tarefas. Sem
/// login (ou antes de verificar o e-mail), tira todos. O `main` escuta.
final localNoticesSyncProvider = Provider<void>((ref) {
  final notices = ref.watch(localNoticesProvider);
  final auth = ref.watch(authStateProvider);
  // Carregando a sessão (ao abrir o app): os avisos de antes ficam.
  if (auth.isLoading && !auth.hasValue) return;
  if (ref.watch(verifiedUidProvider) == null) {
    unawaited(notices.clear());
    return;
  }
  final profile = ref.watch(userProfileProvider).value;
  final plans = ref.watch(plansProvider).value;
  final tasks = ref.watch(tasksProvider).value;
  final allowed = ref.watch(notificationsAllowedProvider).value;
  if (profile == null || plans == null || tasks == null || allowed == null) {
    return;
  }

  final snapshots = <PlanSnapshot>[];
  for (final plan in plans) {
    if (plan.status != PlanStatus.active) continue;
    final snapshot = ref.watch(planSnapshotProvider(plan.id));
    if (snapshot == null) return;
    snapshots.add(snapshot);
  }

  final now = ref.read(clockProvider)();
  final planned = planLocalNotices(
    now: now,
    // Sem permissão, o Aviso da manhã fica desligado.
    morningSummary: allowed
        ? profile.morningSummary
        : profile.morningSummary.copyWith(enabled: false),
    plans: snapshots,
    tasks: tasks,
  );
  // Um novo cálculo antes do prazo descarta este (o provider é refeito).
  final timer = Timer(
    noticesSyncDelay,
    () => unawaited(notices.replaceAll(planned)),
  );
  ref.onDispose(timer.cancel);
});
