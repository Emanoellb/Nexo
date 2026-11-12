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

  /// Excluir conta: apaga tudo o que o aparelho guarda **da conta** [uid]
  /// (foco em andamento, "Permitir durante o uso do app", "Ligar o Não
  /// perturbe ao focar" e os "Primeiros passos"). O que é do aparelho
  /// (primeira abertura, tema, visualização de Tarefas, transparência)
  /// fica.
  Future<void> clearAccount(String uid);
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
  Future<void> clearAccount(String uid) async {
    await _prefs.remove('$_activeFocusPrefix$uid');
    await _prefs.remove('$_dndAllowedPrefix$uid');
    await _prefs.remove('$_dndOnFocusPrefix$uid');
    final done = _prefs.getStringList(_firstStepsDoneKey);
    if (done != null && done.contains(uid)) {
      await _prefs.setStringList(_firstStepsDoneKey, [
        for (final id in done)
          if (id != uid) id,
      ]);
    }
  }

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

/// O `main` troca pelo [SharedPreferencesLocalFlags], que precisa de `await`
/// para abrir (os testes, pelas marcas em memória).
final localFlagsProvider = Provider<LocalFlags>(
  (ref) => throw UnimplementedError(
    'localFlagsProvider: o main passa o SharedPreferencesLocalFlags.',
  ),
);
