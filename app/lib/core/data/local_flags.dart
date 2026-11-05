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
}

/// Implementação com `shared_preferences`. Sem dado pessoal.
class SharedPreferencesLocalFlags implements LocalFlags {
  SharedPreferencesLocalFlags._(this._prefs);

  static const _firstOpenDoneKey = 'first_open_done';
  static const _themePreferenceKey = 'theme_preference';

  static Future<SharedPreferencesLocalFlags> create() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {_firstOpenDoneKey, _themePreferenceKey},
      ),
    );
    return SharedPreferencesLocalFlags._(prefs);
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
  InMemoryLocalFlags({this.firstOpenDone = false, this.themePreference});

  @override
  bool firstOpenDone;

  @override
  String? themePreference;

  @override
  Future<void> markFirstOpenDone() async => firstOpenDone = true;

  @override
  Future<void> setThemePreference(String value) async =>
      themePreference = value;
}

/// O `main` troca pelo [SharedPreferencesLocalFlags] (precisa de `await`).
final localFlagsProvider = Provider<LocalFlags>((ref) => InMemoryLocalFlags());
