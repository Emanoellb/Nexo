import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Marcas e preferências guardadas só no aparelho. Somem se o usuário limpar
/// os dados do app, que é o comportamento desejado para a "primeira abertura"
/// e para o tema.
abstract interface class LocalFlags {
  /// O app já abriu uma vez neste aparelho (splash com boas-vindas vista).
  bool get firstOpenDone;

  Future<void> markFirstOpenDone();

  /// Tema escolhido: `system`, `light` ou `dark`. `null` = nunca escolhido.
  String? get themePreference;

  Future<void> setThemePreference(String value);

  /// A conta [uid] concluiu ou dispensou os "Primeiros passos" do Início
  /// neste aparelho (o cartão não volta).
  bool firstStepsDone(String uid);

  Future<void> markFirstStepsDone(String uid);

  /// Visualização da aba Tarefas: `byDue` (padrão) ou `tabs`. `null` = nunca
  /// escolhida.
  String? get taskView;

  Future<void> setTaskView(String value);

  /// O foco em andamento da conta [uid] (JSON do `ActiveFocus`), para
  /// retomar se o app fechar. `null` = nenhum. Fica só no aparelho até
  /// encerrar.
  String? activeFocus(String uid);

  Future<void> setActiveFocus(String uid, String? json);

  /// A conta [uid] escolheu "Permitir durante o uso do app" no painel do
  /// "Não perturbe" (tela 03): ligar o interruptor não pergunta de novo.
  bool dndAllowed(String uid);

  Future<void> setDndAllowed(String uid);

  /// Perfil: "Reduzir transparência" (a barra de abas sólida). Do
  /// aparelho, não da conta (v0.9: não vai ao Firestore).
  bool get reduceTransparency;

  Future<void> setReduceTransparency(bool value);

  /// Perfil: "Ligar o Não perturbe ao focar", da conta [uid] neste
  /// aparelho (v0.9: não vai ao Firestore). Desligado por padrão.
  bool dndOnFocus(String uid);

  Future<void> setDndOnFocus(String uid, bool value);
}

/// Implementação com `shared_preferences`. Sem dado pessoal: só o uid
/// opaco da conta, que já fica no aparelho pela sessão.
class SharedPreferencesLocalFlags implements LocalFlags {
  SharedPreferencesLocalFlags._(this._prefs);

  static const _firstOpenDoneKey = 'first_open_done';
  static const _themePreferenceKey = 'theme_preference';
  static const _firstStepsDoneKey = 'first_steps_done';
  static const _taskViewKey = 'task_view';
  static const _activeFocusPrefix = 'active_focus_';
  static const _dndAllowedPrefix = 'dnd_allowed_';
  static const _reduceTransparencyKey = 'reduce_transparency';
  static const _dndOnFocusPrefix = 'dnd_on_focus_';

  static Future<SharedPreferencesLocalFlags> create() async {
    final prefs = await SharedPreferencesWithCache.create(
      // Sem lista fechada de chaves: o foco em andamento usa uma chave por
      // conta (`active_focus_{uid}`).
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    return SharedPreferencesLocalFlags._(prefs);
  }

  @override
  String? get taskView => _prefs.getString(_taskViewKey);

  @override
  Future<void> setTaskView(String value) =>
      _prefs.setString(_taskViewKey, value);

  @override
  bool firstStepsDone(String uid) =>
      (_prefs.getStringList(_firstStepsDoneKey) ?? const []).contains(uid);

  @override
  Future<void> markFirstStepsDone(String uid) {
    final done = {...?_prefs.getStringList(_firstStepsDoneKey), uid};
    return _prefs.setStringList(_firstStepsDoneKey, done.toList());
  }

  final SharedPreferencesWithCache _prefs;

  @override
  String? activeFocus(String uid) =>
      _prefs.getString('$_activeFocusPrefix$uid');

  @override
  Future<void> setActiveFocus(String uid, String? json) => json == null
      ? _prefs.remove('$_activeFocusPrefix$uid')
      : _prefs.setString('$_activeFocusPrefix$uid', json);

  @override
  bool get reduceTransparency =>
      _prefs.getBool(_reduceTransparencyKey) ?? false;

  @override
  Future<void> setReduceTransparency(bool value) =>
      _prefs.setBool(_reduceTransparencyKey, value);

  @override
  bool dndOnFocus(String uid) =>
      _prefs.getBool('$_dndOnFocusPrefix$uid') ?? false;

  @override
  Future<void> setDndOnFocus(String uid, bool value) =>
      _prefs.setBool('$_dndOnFocusPrefix$uid', value);

  @override
  bool dndAllowed(String uid) =>
      _prefs.getBool('$_dndAllowedPrefix$uid') ?? false;

  @override
  Future<void> setDndAllowed(String uid) =>
      _prefs.setBool('$_dndAllowedPrefix$uid', true);

  @override
  bool get firstOpenDone => _prefs.getBool(_firstOpenDoneKey) ?? false;

  @override
  Future<void> markFirstOpenDone() => _prefs.setBool(_firstOpenDoneKey, true);

  @override
  String? get themePreference => _prefs.getString(_themePreferenceKey);

  @override
  Future<void> setThemePreference(String value) =>
      _prefs.setString(_themePreferenceKey, value);
}

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

/// O `main` troca pelo [SharedPreferencesLocalFlags] (precisa de `await`).
final localFlagsProvider = Provider<LocalFlags>((ref) => InMemoryLocalFlags());
