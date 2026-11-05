import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/subjects_repository.dart';
import '../domain/subject.dart';

/// Na prototipação, o fake em memória; no bloco de integração, o Firestore.
/// Um por conta: trocar de conta recria (dados de `users/{uid}`).
final subjectsRepositoryProvider = Provider<SubjectsRepository>((ref) {
  ref.watch(currentUidProvider);
  final repository = FakeSubjectsRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final subjectsProvider = StreamProvider<List<Subject>>(
  (ref) => ref.watch(subjectsRepositoryProvider).watchSubjects(),
);
