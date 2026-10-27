import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Marcas guardadas só no aparelho. Somem se o usuário limpar os dados do
/// app, que é o comportamento desejado para a "primeira abertura".
abstract interface class LocalFlags {
  /// O app já abriu uma vez neste aparelho (splash com boas-vindas vista).
  bool get firstOpenDone;

  Future<void> markFirstOpenDone();
}

/// Implementação com `shared_preferences`. Sem dado pessoal.
class SharedPreferencesLocalFlags implements LocalFlags {
  SharedPreferencesLocalFlags._(this._prefs);

  static const _firstOpenDoneKey = 'first_open_done';

  static Future<SharedPreferencesLocalFlags> create() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {_firstOpenDoneKey},
      ),
    );
    return SharedPreferencesLocalFlags._(prefs);
  }

  final SharedPreferencesWithCache _prefs;

  @override
  bool get firstOpenDone => _prefs.getBool(_firstOpenDoneKey) ?? false;

  @override
  Future<void> markFirstOpenDone() => _prefs.setBool(_firstOpenDoneKey, true);
}

/// Em memória: testes e qualquer execução sem o `main` real.
class InMemoryLocalFlags implements LocalFlags {
  InMemoryLocalFlags({this.firstOpenDone = false});

  @override
  bool firstOpenDone;

  @override
  Future<void> markFirstOpenDone() async => firstOpenDone = true;
}

/// O `main` troca pelo [SharedPreferencesLocalFlags] (precisa de `await`).
final localFlagsProvider = Provider<LocalFlags>((ref) => InMemoryLocalFlags());
