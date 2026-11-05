import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_flags.dart';

/// Tema do app: Sistema · Claro · Escuro (decisão de 04/11/2026). Começa
/// seguindo o sistema e guarda a escolha só no aparelho. A opção na tela
/// vem com o Perfil.
final themePreferenceProvider = NotifierProvider<ThemePreference, ThemeMode>(
  ThemePreference.new,
);

class ThemePreference extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => _decode(ref.read(localFlagsProvider).themePreference);

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(localFlagsProvider).setThemePreference(mode.name);
  }

  /// Valor desconhecido (ou nunca escolhido) volta para o sistema.
  static ThemeMode _decode(String? value) => ThemeMode.values.firstWhere(
    (m) => m.name == value,
    orElse: () => ThemeMode.system,
  );
}
