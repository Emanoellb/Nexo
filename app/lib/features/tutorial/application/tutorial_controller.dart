import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';

/// Passos do tutorial (roteiro do usuário, 26/10/2026). Depois deles vem a
/// tela "Tudo pronto", que não conta como passo.
abstract final class TutorialSteps {
  static const count = 5;

  /// Índice da tela "Tudo pronto" (depois do último passo).
  static const done = count;
}

@immutable
class TutorialState {
  const TutorialState({
    this.page = 0,
    this.plays = const {},
    this.finishing = false,
  });

  /// 0 a 4: passos; [TutorialSteps.done]: "Tudo pronto".
  final int page;

  /// Quantas vezes a animação de cada página já foi pedida. Muda ao entrar
  /// na página e no "Repetir animação"; a ilustração reinicia quando muda.
  final Map<int, int> plays;

  /// "Começar" em andamento (gravando `tutorialSeen`).
  final bool finishing;

  bool get isDone => page == TutorialSteps.done;

  int playsOf(int page) => plays[page] ?? 0;

  TutorialState copyWith({int? page, Map<int, int>? plays, bool? finishing}) =>
      TutorialState(
        page: page ?? this.page,
        plays: plays ?? this.plays,
        finishing: finishing ?? this.finishing,
      );
}

/// Estado da tela 06 (boas-vindas + tutorial). A navegação depois do
/// "Começar" fica com o redirecionamento do roteador: com `tutorialSeen`, o
/// usuário vai ao Início.
class TutorialController extends Notifier<TutorialState> {
  @override
  TutorialState build() => const TutorialState(plays: {0: 1});

  /// Entrou na página [page] (botão ou gesto): a animação dela toca.
  void showPage(int page) {
    if (page == state.page) return;
    state = state.copyWith(
      page: page,
      plays: {...state.plays, page: state.playsOf(page) + 1},
    );
  }

  void next() => showPage(state.page + 1);

  void previous() {
    if (state.page > 0) showPage(state.page - 1);
  }

  /// "Pular": vai para o "Tudo pronto" (decisão do usuário, 28/10/2026).
  void skip() => showPage(TutorialSteps.done);

  /// "Repetir animação" do passo atual.
  void replay() => state = state.copyWith(
    plays: {...state.plays, state.page: state.playsOf(state.page) + 1},
  );

  /// "Começar": grava `tutorialSeen` e o roteador leva ao Início.
  Future<void> finish() async {
    if (state.finishing) return;
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    final profiles = ref.read(userProfileRepositoryProvider);
    state = state.copyWith(finishing: true);
    try {
      await profiles.markTutorialSeen(uid);
    } finally {
      if (ref.mounted) state = state.copyWith(finishing: false);
    }
  }
}

final tutorialControllerProvider =
    NotifierProvider.autoDispose<TutorialController, TutorialState>(
      TutorialController.new,
    );
