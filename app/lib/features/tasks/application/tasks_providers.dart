import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/clock.dart';
import '../../auth/application/auth_providers.dart';
import '../../../core/data/firestore_access.dart';
import '../data/firestore_tasks_repository.dart';
import '../data/tasks_repository.dart';
import '../domain/task.dart';

/// Firestore (`users/{uid}/…`), com o uid verificado: sem login ou antes de
/// verificar o e-mail, listas vazias. Trocar de conta recria.
final tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) => FirestoreTasksRepository(
    ref.watch(firestoreAccessProvider),
    uid: ref.watch(verifiedUidProvider),
    clock: ref.watch(clockProvider),
  ),
);

final tasksProvider = StreamProvider<List<NexoTask>>(
  (ref) => ref.watch(tasksRepositoryProvider).watchTasks(),
);
