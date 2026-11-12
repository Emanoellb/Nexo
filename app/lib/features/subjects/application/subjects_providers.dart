import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../../core/data/firestore_access.dart';
import '../data/firestore_subjects_repository.dart';
import '../data/subjects_repository.dart';
import '../domain/subject.dart';

/// Firestore (`users/{uid}/…`), com o uid verificado: sem login ou antes de
/// verificar o e-mail, listas vazias. Trocar de conta recria.
final subjectsRepositoryProvider = Provider<SubjectsRepository>(
  (ref) => FirestoreSubjectsRepository(
    ref.watch(firestoreAccessProvider),
    uid: ref.watch(verifiedUidProvider),
  ),
);

final subjectsProvider = StreamProvider<List<Subject>>(
  (ref) => ref.watch(subjectsRepositoryProvider).watchSubjects(),
);
