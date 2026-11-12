import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/domain/entry_status.dart';

import '../../fakes/fakes.dart';

/// Achado [3] da revisão: na troca de usuário, o perfil anterior (`null`)
/// não pode ser lido como "sem perfil", senão o roteador passa pela 03b.
void main() {
  test('login com perfil completo nunca passa por completeProfile', () async {
    final auth = FakeAuthRepository(withPrototypeAccounts: true);
    final container = ProviderContainer(
      overrides: [
        ...fakeBackend(
          auth: auth,
          profiles: FakeUserProfileRepository.prototype(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final statuses = <EntryStatus>[];
    container.listen<EntryStatus>(
      entryStatusProvider,
      (_, next) => statuses.add(next),
      fireImmediately: true,
    );
    await pumpEventQueue();
    expect(statuses.last, EntryStatus.signedOut);

    await auth.signInWithEmail(
      email: FakeAuthRepository.prototypeEmail,
      password: FakeAuthRepository.prototypePassword,
    );
    await pumpEventQueue();

    expect(statuses.last, EntryStatus.ready);
    expect(statuses, isNot(contains(EntryStatus.completeProfile)));
  });
}
