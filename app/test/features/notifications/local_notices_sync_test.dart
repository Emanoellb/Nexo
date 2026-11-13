import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/clock.dart';
import 'package:nexo/core/domain/local_date.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/notifications/application/local_notices.dart';
import 'package:nexo/features/notifications/domain/local_notice.dart';
import 'package:nexo/features/plans/application/plans_providers.dart';
import 'package:nexo/features/plans/domain/plan.dart';
import 'package:nexo/features/plans/domain/plan_schedule.dart';

import '../../fakes/fakes.dart';

// Quarta, 11/11/2026, 10:00.
final _now = DateTime(2026, 11, 11, 10);

Future<void> _waitSync() =>
    Future<void>.delayed(noticesSyncDelay + const Duration(milliseconds: 200));

void main() {
  test('agenda ao entrar, refaz a cada mudança e limpa ao sair', () async {
    final auth = FakeAuthRepository.signedIn();
    final spy = SpyLocalNotices();
    final container = ProviderContainer(
      overrides: [
        ...fakeBackend(auth: auth),
        clockProvider.overrideWithValue(() => _now),
        localNoticesProvider.overrideWithValue(spy),
      ],
    );
    addTearDown(container.dispose);
    container.listen(localNoticesSyncProvider, (_, _) {});
    await container.read(authStateProvider.future);
    await _waitSync();

    // Sem planos nem tarefas: só o aviso da manhã, que sem nada no dia não
    // sai.
    expect(spy.scheduled.last, isEmpty);

    await container
        .read(plansRepositoryProvider)
        .createPlan(
          Plan(
            id: '',
            name: 'Concurso',
            startDate: const LocalDate(2026, 11, 10),
            endDate: const LocalDate(2027, 3, 1),
            frequency: const DailyFrequency(),
            dailyGoalMinutes: 90,
          ),
        );
    await _waitSync();
    final withPlan = spy.scheduled.last;
    expect(withPlan.any((n) => n.title == 'Concurso'), isTrue);
    expect(withPlan.any((n) => n.channel == NoticeChannel.daySummary), isTrue);

    await auth.signOut();
    await _waitSync();
    expect(spy.clears, greaterThan(0));
  });

  test('sem permissão, o Aviso da manhã não é agendado', () async {
    final spy = SpyLocalNotices(allowed: false);
    final container = ProviderContainer(
      overrides: [
        ...fakeBackend(auth: FakeAuthRepository.signedIn()),
        clockProvider.overrideWithValue(() => _now),
        localNoticesProvider.overrideWithValue(spy),
      ],
    );
    addTearDown(container.dispose);
    container.listen(localNoticesSyncProvider, (_, _) {});
    await container.read(authStateProvider.future);
    await container
        .read(plansRepositoryProvider)
        .createPlan(
          Plan(
            id: '',
            name: 'Concurso',
            startDate: const LocalDate(2026, 11, 10),
            endDate: const LocalDate(2027, 3, 1),
            frequency: const DailyFrequency(),
            dailyGoalMinutes: 90,
          ),
        );
    await _waitSync();
    final notices = spy.scheduled.last;
    expect(notices.any((n) => n.title == 'Concurso'), isTrue);
    expect(notices.any((n) => n.channel == NoticeChannel.daySummary), isFalse);
  });
}
