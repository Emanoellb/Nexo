import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A carga do Firebase (`Firebase.initializeApp`), que roda durante a
/// splash. Os repositórios reais (Auth, Firestore) esperam por ela antes de
/// usar o Firebase. O `main` troca pela carga de verdade; nos testes os
/// repositórios são falsos e isto não é usado.
final firebaseReadyProvider = Provider<Future<void>>((ref) => Future.value());

/// Fuso IANA aceito pelas regras (`users.timeZone`): "America/Sao_Paulo",
/// "Etc/GMT+3". Fora disso (ex.: "GMT+03:00"), o padrão do Brasil.
String normalizeTimeZone(String? id) {
  const fallback = 'America/Sao_Paulo';
  if (id == null || id.isEmpty || id.length > 64) return fallback;
  final valid = RegExp(r'^[A-Za-z_]+(/[A-Za-z0-9_+-]+){0,2}$').hasMatch(id);
  return valid ? id : fallback;
}
