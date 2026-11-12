import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/domain/auth_user.dart';

import '../../fakes/fakes.dart';

/// Conta quem pediu para escutar `users/{uid}`.
class _SpyProfiles extends FakeUserProfileRepository {
  final watched = <String>[];

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    watched.add(uid);
    return super.watchProfile(uid);
  }
}

void main() {
  test('só escuta users/{uid} depois da verificação do e-mail', () async {
    const user = AuthUser(uid: 'u1', emailVerified: false, email: 'a@b.com');
    final auth = FakeAuthRepository(initialUser: user);
    final profiles = _SpyProfiles();
    final container = ProviderContainer(
      overrides: [...fakeBackend(auth: auth, profiles: profiles)],
    );
    addTearDown(container.dispose);
    container.listen(userProfileProvider, (_, _) {});

    await container.read(authStateProvider.future);
    await container.read(userProfileProvider.future);
    // Antes de verificar, as regras recusariam a leitura.
    expect(profiles.watched, isEmpty);

    auth.setUser(user.copyWith(emailVerified: true));
    await Future<void>.delayed(Duration.zero);
    await container.read(userProfileProvider.future);
    expect(profiles.watched, ['u1']);
  });
}
