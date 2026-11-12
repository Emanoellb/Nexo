import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/data/data_failure.dart';
import 'package:nexo/features/auth/application/account_deletion.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';

import '../../fakes/fakes.dart';

/// A marca de exclusão não chega ao servidor.
class _FailingProfiles extends FakeUserProfileRepository {
  @override
  Future<void> markDeletionRequested(String uid) async =>
      throw const DataFailure(DataFailureCode.permissionDenied);
}

void main() {
  test('sem a marca no servidor, a entrada sai de "Excluindo"', () async {
    final container = ProviderContainer(
      overrides: [
        ...fakeBackend(
          auth: FakeAuthRepository(
            initialUser: FakeAuthRepository.prototypeUser,
          ),
          profiles: _FailingProfiles(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(authStateProvider, (_, _) {});
    await container.read(authStateProvider.future);

    await expectLater(
      container.read(accountDeletionProvider).request(),
      throwsA(isA<DataFailure>()),
    );
    expect(container.read(accountDeletionRunningProvider), isFalse);
  });
}
