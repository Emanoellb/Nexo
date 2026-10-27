import 'dart:async';

import '../domain/auth_user.dart';
import 'auth_repository.dart';

/// Auth em memória para a prototipação (dados fake primeiro, decisão de
/// 26/10/2026). Não toca no Firebase.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? initialUser}) : _user = initialUser;

  /// Usuário de exemplo, verificado e com o tutorial já visto no perfil fake.
  factory FakeAuthRepository.prototype() =>
      FakeAuthRepository(initialUser: prototypeUser);

  static const prototypeUser = AuthUser(uid: 'prototipo', emailVerified: true);

  AuthUser? _user;
  final _controller = StreamController<AuthUser?>.broadcast();

  AuthUser? get currentUser => _user;

  /// Para testes e protótipo: troca o usuário e avisa quem escuta.
  void setUser(AuthUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  Future<void> signOut() async => setUser(null);

  void dispose() => _controller.close();
}

/// `users/{uid}` em memória.
class FakeUserProfileRepository implements UserProfileRepository {
  FakeUserProfileRepository({Map<String, UserProfile>? profiles})
    : _profiles = {...?profiles};

  factory FakeUserProfileRepository.prototype() => FakeUserProfileRepository(
    profiles: {
      FakeAuthRepository.prototypeUser.uid: const UserProfile(
        displayName: 'Ana',
        tutorialSeen: true,
      ),
    },
  );

  final Map<String, UserProfile> _profiles;
  final _controller = StreamController<String>.broadcast();

  void setProfile(String uid, UserProfile? profile) {
    if (profile == null) {
      _profiles.remove(uid);
    } else {
      _profiles[uid] = profile;
    }
    _controller.add(uid);
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) async* {
    yield _profiles[uid];
    yield* _controller.stream
        .where((changed) => changed == uid)
        .map((_) => _profiles[uid]);
  }

  void dispose() => _controller.close();
}
