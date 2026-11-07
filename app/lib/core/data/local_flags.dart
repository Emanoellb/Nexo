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
}

/// Implementação com `shared_preferences`. Sem dado pessoal: só o uid
/// opaco da conta, que já fica no aparelho pela sessão.
class SharedPreferencesLocalFlags implements LocalFlags {
  SharedPreferencesLocalFlags._(this._prefs);

  static const _firstOpenDoneKey = 'first_open_done';
  static const _themePreferenceKey = 'theme_preference';
  static const _firstStepsDoneKey = 'first_steps_done';
  static const _taskViewKey = 'task_view';

  static Future<SharedPreferencesLocalFlags> create() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {
          _firstOpenDoneKey,
          _themePreferenceKey,
          _firstStepsDoneKey,
          _taskViewKey,
        },
      ),
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

  @override
  Future<void> setThemePreference(String value) async =>
      themePreference = value;
}

/// O `main` troca pelo [SharedPreferencesLocalFlags] (precisa de `await`).
final localFlagsProvider = Provider<LocalFlags>((ref) => InMemoryLocalFlags());
