import 'package:nexo/core/data/local_flags.dart';

/// Em memória: testes e qualquer execução sem o `main` real.
class InMemoryLocalFlags implements LocalFlags {
  InMemoryLocalFlags({
    this.firstOpenDone = false,
    this.themePreference,
    this.taskView,
    Set<String>? firstStepsDoneFor,
  }) : firstStepsDoneFor = {...?firstStepsDoneFor};

  @override
  bool firstOpenDone;

  @override
  String? themePreference;

  @override
  String? taskView;

  @override
  Future<void> setTaskView(String value) async => taskView = value;

  /// Contas que concluíram ou dispensaram os "Primeiros passos".
  final Set<String> firstStepsDoneFor;

  @override
  bool firstStepsDone(String uid) => firstStepsDoneFor.contains(uid);

  @override
  Future<void> markFirstStepsDone(String uid) async =>
      firstStepsDoneFor.add(uid);

  @override
  Future<void> markFirstOpenDone() async => firstOpenDone = true;

  /// Foco em andamento por conta (JSON).
  final Map<String, String> activeFocusByUid = {};

  /// Contas com "Permitir durante o uso do app" no "Não perturbe".
  final Set<String> dndAllowedFor = {};

  @override
  bool reduceTransparency = false;

  @override
  Future<void> setReduceTransparency(bool value) async =>
      reduceTransparency = value;

  /// Contas com "Ligar o Não perturbe ao focar".
  final Set<String> dndOnFocusFor = {};

  @override
  bool dndOnFocus(String uid) => dndOnFocusFor.contains(uid);

  @override
  Future<void> setDndOnFocus(String uid, bool value) async =>
      value ? dndOnFocusFor.add(uid) : dndOnFocusFor.remove(uid);

  @override
  Future<void> clearAccount(String uid) async {
    activeFocusByUid.remove(uid);
    dndAllowedFor.remove(uid);
    dndOnFocusFor.remove(uid);
    firstStepsDoneFor.remove(uid);
  }

  @override
  bool dndAllowed(String uid) => dndAllowedFor.contains(uid);

  @override
  Future<void> setDndAllowed(String uid) async => dndAllowedFor.add(uid);

  @override
  String? activeFocus(String uid) => activeFocusByUid[uid];

  @override
  Future<void> setActiveFocus(String uid, String? json) async {
    if (json == null) {
      activeFocusByUid.remove(uid);
    } else {
      activeFocusByUid[uid] = json;
    }
  }

  @override
  Future<void> setThemePreference(String value) async =>
      themePreference = value;
}
