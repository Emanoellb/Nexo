import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/data/local_flags.dart';
import 'package:nexo/features/auth/application/account_deletion.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/data/auth_repository.dart';
import 'package:nexo/features/goals/application/goals_providers.dart';
import 'package:nexo/features/legal/data/legal_documents_repository.dart';
import 'package:nexo/features/notifications/application/notifications_providers.dart';
import 'package:nexo/features/notifications/data/notifications_repository.dart';
import 'package:nexo/features/plans/application/plans_providers.dart';
import 'package:nexo/features/progress/application/achievements_providers.dart';
import 'package:nexo/features/subjects/application/subjects_providers.dart';
import 'package:nexo/features/subjects/data/subjects_repository.dart';
import 'package:nexo/features/tasks/application/tasks_providers.dart';

import 'fake_achievements_repository.dart';
import 'fake_auth_repository.dart';
import 'fake_goals_repository.dart';
import 'fake_legal_documents_repository.dart';
import 'fake_notifications_repository.dart';
import 'fake_plans_repository.dart';
import 'fake_subjects_repository.dart';
import 'fake_tasks_repository.dart';
import 'fake_user_data_eraser.dart';
import 'in_memory_local_flags.dart';

/// Os providers de `lib/` usam o Firebase (Auth e Firestore) e as marcas do
/// aparelho. Nos testes, estes overrides voltam aos fakes em memória, como
/// na prototipação:
/// - o Auth em memória, com a conta de protótipo (Ana) e a espera simulada;
/// - o perfil da Ana;
/// - os repositórios de dados por conta (trocar de conta recria);
/// - as versões legais técnicas;
/// - o sino em memória;
/// - a exclusão de dados sem nada a apagar;
/// - as marcas locais em memória.
///
/// Um teste que troca um destes passa o seu pelo parâmetro: o Riverpod não
/// deixa trocar o mesmo provider duas vezes.
List<Override> fakeBackend({
  AuthRepository? auth,
  UserProfileRepository? profiles,
  LegalDocumentsRepository? legal,
  SubjectsRepository? subjects,
  NotificationsRepository? notifications,
  LocalFlags? flags,
}) => [
  if (auth != null)
    authRepositoryProvider.overrideWithValue(auth)
  else
    authRepositoryProvider.overrideWith((ref) {
      final repository = FakeAuthRepository.prototype();
      ref.onDispose(repository.dispose);
      return repository;
    }),
  if (profiles != null)
    userProfileRepositoryProvider.overrideWithValue(profiles)
  else
    userProfileRepositoryProvider.overrideWith((ref) {
      final repository = FakeUserProfileRepository.prototype();
      ref.onDispose(repository.dispose);
      return repository;
    }),
  legalDocumentsRepositoryProvider.overrideWithValue(
    legal ?? const FakeLegalDocumentsRepository(),
  ),
  plansRepositoryProvider.overrideWith((ref) {
    ref.watch(currentUidProvider);
    final repository = FakePlansRepository(clock: ref.watch(clockProvider));
    ref.onDispose(repository.dispose);
    return repository;
  }),
  tasksRepositoryProvider.overrideWith((ref) {
    ref.watch(currentUidProvider);
    final repository = FakeTasksRepository(clock: ref.watch(clockProvider));
    ref.onDispose(repository.dispose);
    return repository;
  }),
  if (subjects != null)
    subjectsRepositoryProvider.overrideWithValue(subjects)
  else
    subjectsRepositoryProvider.overrideWith((ref) {
      ref.watch(currentUidProvider);
      final repository = FakeSubjectsRepository();
      ref.onDispose(repository.dispose);
      return repository;
    }),
  goalsRepositoryProvider.overrideWith((ref) {
    ref.watch(currentUidProvider);
    final repository = FakeGoalsRepository();
    ref.onDispose(repository.dispose);
    return repository;
  }),
  achievementsRepositoryProvider.overrideWith((ref) {
    ref.watch(currentUidProvider);
    final repository = FakeAchievementsRepository(
      clock: ref.watch(clockProvider),
    );
    ref.onDispose(repository.dispose);
    return repository;
  }),
  if (notifications != null)
    notificationsRepositoryProvider.overrideWithValue(notifications)
  else
    notificationsRepositoryProvider.overrideWith((ref) {
      ref.watch(currentUidProvider);
      final repository = FakeNotificationsRepository(
        clock: ref.watch(clockProvider),
      );
      ref.onDispose(repository.dispose);
      return repository;
    }),
  userDataEraserProvider.overrideWithValue(const FakeUserDataEraser()),
  localFlagsProvider.overrideWithValue(flags ?? InMemoryLocalFlags()),
];
