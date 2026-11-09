import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../../../core/data/local_flags.dart';
import '../../auth/application/auth_providers.dart';
import '../../plans/application/plans_providers.dart';
import '../../plans/application/plan_today.dart';
import '../../progress/application/progress_actions.dart';
import '../../../core/domain/local_date.dart';
import '../../plans/domain/plan_day_result.dart';
import '../domain/active_focus.dart';
import '../domain/focus_session.dart';
import '../domain/session_split.dart';
import 'focus_system.dart';

/// Resultado de "Encerrar".
sealed class FocusFinish {
  const FocusFinish();
}

/// Menos de 1 min: não salva ("Sessão muito curta para salvar.").
final class FocusTooShort extends FocusFinish {
  const FocusTooShort(this.focus);

  /// O foco descartado, para o "Desfazer" devolver.
  final ActiveFocus focus;
}

/// Salvo: as sessões gravadas (divididas à meia-noite, se for o caso).
final class FocusSaved extends FocusFinish {
  const FocusSaved({
    required this.planId,
    required this.sessions,
    required this.metGoalNow,
  });

  final String planId;
  final List<FocusSession> sessions;

  /// A sessão fez a meta de hoje ser batida agora ("Meta do dia batida!").
  final bool metGoalNow;

  int get minutes => sessions.fold(0, (sum, s) => sum + s.minutes);
}

/// O foco em andamento da conta atual, guardado no aparelho (sobrevive ao
/// app fechar). `null` = nenhum.
class ActiveFocusNotifier extends Notifier<ActiveFocus?> {
  @override
  ActiveFocus? build() {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return null;
    final flags = ref.read(localFlagsProvider);
    var focus = ActiveFocus.fromJson(flags.activeFocus(uid));
    if (focus == null) return null;
    // Guardado com o "Não perturbe" ligado, mas de antes de o app fechar:
    // a abertura já desligou o modo (AndroidFocusSystem.init).
    if (focus.dnd && !ref.read(focusSystemProvider).dndOnSinceLaunch) {
      focus = focus.copyWith(dnd: false);
      unawaited(flags.setActiveFocus(uid, focus.toJson()));
    }
    // A notificação some num reinício do aparelho: volta com o app.
    final restored = focus;
    Future.microtask(() => _showOngoing(restored));
    return focus;
  }

  DateTime get _now => ref.read(clockProvider)();

  Future<void> _set(ActiveFocus? focus) async {
    state = focus;
    final uid = ref.read(currentUidProvider);
    if (uid != null) {
      await ref.read(localFlagsProvider).setActiveFocus(uid, focus?.toJson());
    }
    if (focus != null) await _showOngoing(focus);
  }

  /// A notificação fixa com o plano e os tópicos ("Concurso · Português").
  Future<void> _showOngoing(ActiveFocus focus) async {
    final repository = ref.read(plansRepositoryProvider);
    final plan = await repository.watchPlan(focus.planId).first;
    final topics = await repository.watchTopics(focus.planId).first;
    final names = {for (final t in topics) t.id: t.name};
    // Encerrado ou trocado enquanto lia: não volta a mostrar.
    if (!ref.mounted || state != focus) return;
    final detail = [
      plan?.name ?? 'Foco',
      for (final id in focus.topicIds)
        if (names[id] != null) names[id]!,
    ].join(' · ');
    await ref.read(focusSystemProvider).showOngoing(focus, detail: detail);
  }

  /// "Focar" começa na hora. Com um foco já em andamento, fica com ele. No
  /// primeiro foco, o Android 13+ pergunta pelas notificações antes.
  Future<ActiveFocus> start(String planId) =>
      _starting ??= _start(planId).whenComplete(() => _starting = null);

  /// Um "Focar" esperando a resposta da permissão (dois toques = um foco).
  Future<ActiveFocus>? _starting;

  Future<ActiveFocus> _start(String planId) async {
    final current = state;
    if (current != null) return current;
    // O tempo só começa depois de a pessoa responder (permitir ou não).
    await ref.read(focusSystemProvider).requestNotificationPermission();
    final focus = ActiveFocus(planId: planId, startedAt: _now);
    await _set(focus);
    return focus;
  }

  Future<void> pause() async {
    final focus = state;
    if (focus != null) await _set(focus.pause(_now));
  }

  Future<void> resume() async {
    final focus = state;
    if (focus != null) await _set(focus.resume(_now));
  }

  Future<void> setTopics(List<String> topicIds) async {
    final focus = state;
    if (focus != null) await _set(focus.copyWith(topicIds: topicIds));
  }

  /// Liga ou desliga o "Não perturbe" deste foco.
  Future<void> setDnd({required bool on}) async {
    final focus = state;
    if (focus == null) return;
    final done = await ref.read(focusSystemProvider).setDnd(on: on);
    await _set(focus.copyWith(dnd: on && done));
  }

  /// Devolve um foco (o "Desfazer" da sessão curta ou do descartar). O
  /// "Não perturbe" foi desligado ao tirar o foco e volta desligado.
  Future<void> restore(ActiveFocus focus) => _set(
    focus.copyWith(
      dnd: focus.dnd && ref.read(focusSystemProvider).dndOnSinceLaunch,
    ),
  );

  /// Tira o foco (encerrado ou descartado): o "Não perturbe" volta ao estado
  /// de antes e a notificação fixa sai.
  Future<void> clear() async {
    final focus = state;
    final system = ref.read(focusSystemProvider);
    if (focus != null && focus.dnd) await system.setDnd(on: false);
    await system.clearOngoing();
    await _set(null);
  }
}

final activeFocusProvider = NotifierProvider<ActiveFocusNotifier, ActiveFocus?>(
  ActiveFocusNotifier.new,
);

/// O "agora" do cronômetro: renova a cada segundo enquanto há foco.
final focusNowProvider = StreamProvider<DateTime>((ref) async* {
  final clock = ref.watch(clockProvider);
  yield clock();
  if (ref.watch(activeFocusProvider) == null) return;
  yield* Stream.periodic(const Duration(seconds: 1), (_) => clock());
});

/// Encerrar, descartar e desfazer (pontos e meta ajustados pelo
/// `ProgressActions`).
class FocusActions {
  FocusActions(this._ref);

  final Ref _ref;

  /// "Salvar sessão" (ou a sessão curta, que não é salva). Os tópicos e a
  /// nota vêm do painel de encerrar.
  Future<FocusFinish?> finish({
    required List<String> topicIds,
    String? note,
  }) async {
    final notifier = _ref.read(activeFocusProvider.notifier);
    final focus = _ref.read(activeFocusProvider);
    if (focus == null) return null;
    final now = _ref.read(clockProvider)();
    if (focus.elapsed(now) < ActiveFocus.minimum) {
      await notifier.clear();
      return FocusTooShort(focus);
    }
    final today = LocalDate.fromDateTime(now);
    // Lido antes de gravar (a meta já estava batida?).
    final metBefore = await _metToday(focus.planId, today);
    final segments = splitSessionByDay(focus.intervals(now));
    final sessions = await _ref
        .read(progressActionsProvider)
        .addSessions(
          focus.planId,
          segments,
          source: SessionSource.focus,
          topicIds: topicIds,
          note: note,
        );
    await notifier.clear();
    final metNow = await _metToday(focus.planId, today);
    return FocusSaved(
      planId: focus.planId,
      sessions: sessions,
      metGoalNow: !metBefore && metNow,
    );
  }

  /// "Desfazer" do salvar: apaga as sessões gravadas.
  Future<void> undoSave(FocusSaved saved) => _ref
      .read(progressActionsProvider)
      .deleteSessions(saved.planId, saved.sessions);

  /// A meta de [day] está batida (na meta ou acima) no plano.
  Future<bool> _metToday(String planId, LocalDate day) async {
    final repository = _ref.read(plansRepositoryProvider);
    final plan = await repository.watchPlan(planId).first;
    if (plan == null) return false;
    final snapshot = PlanSnapshot(
      plan: plan,
      versions: await repository.watchVersions(planId).first,
      days: await repository.watchDays(planId).first,
    );
    final result = planDayResult(snapshot, day, today: day);
    return result.status == PlanDayStatus.met ||
        result.status == PlanDayStatus.metOver;
  }
}

final focusActionsProvider = Provider<FocusActions>(FocusActions.new);

/// O plano do foco hoje (para o cronômetro: "Hoje: 1h 09min de 1h 30min").
final focusPlanTodayProvider = Provider<PlanToday?>((ref) {
  final focus = ref.watch(activeFocusProvider);
  if (focus == null) return null;
  return ref.watch(planTodayProvider(focus.planId));
});
