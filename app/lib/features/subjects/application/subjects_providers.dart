import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/subjects_repository.dart';
import '../domain/subject.dart';

/// Na prototipação, o fake em memória; no bloco de integração, o Firestore.
final subjectsRepositoryProvider = Provider<SubjectsRepository>((ref) {
  final repository = FakeSubjectsRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final subjectsProvider = StreamProvider<List<Subject>>(
  (ref) => ref.watch(subjectsRepositoryProvider).watchSubjects(),
);
