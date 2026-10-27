import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/app/router/entry_redirect.dart';
import 'package:nexo/app/router/routes.dart';
import 'package:nexo/features/auth/domain/auth_user.dart';
import 'package:nexo/features/auth/domain/entry_status.dart';

void main() {
  group('resolveEntryStatus', () {
    const verified = AuthUser(uid: 'u1', emailVerified: true);
    const unverified = AuthUser(uid: 'u1', emailVerified: false);
    const seen = UserProfile(displayName: 'Ana', tutorialSeen: true);
    const notSeen = UserProfile(displayName: 'Ana');

    EntryStatus resolve({
      bool authLoading = false,
      AuthUser? user,
      bool profileLoading = false,
      UserProfile? profile,
    }) => resolveEntryStatus(
      authLoading: authLoading,
      user: user,
      profileLoading: profileLoading,
      profile: profile,
    );

    test('auth carregando → loading', () {
      expect(resolve(authLoading: true), EntryStatus.loading);
    });
    test('sem usuário → signedOut', () {
      expect(resolve(), EntryStatus.signedOut);
    });
    test('e-mail não verificado → verifyEmail, mesmo com perfil', () {
      expect(resolve(user: unverified, profile: seen), EntryStatus.verifyEmail);
    });
    test('verificado com perfil carregando → loading', () {
      expect(
        resolve(user: verified, profileLoading: true),
        EntryStatus.loading,
      );
    });
    test('verificado sem users/{uid} (Google) → completeProfile', () {
      expect(resolve(user: verified), EntryStatus.completeProfile);
    });
    test('tutorial não visto → tutorial', () {
      expect(resolve(user: verified, profile: notSeen), EntryStatus.tutorial);
    });
    test('tudo certo → ready', () {
      expect(resolve(user: verified, profile: seen), EntryStatus.ready);
    });
  });

  group('entryRedirect', () {
    test('loading leva à Splash e fica nela', () {
      expect(
        entryRedirect(EntryStatus.loading, AppRoutes.home),
        AppRoutes.splash,
      );
      expect(entryRedirect(EntryStatus.loading, AppRoutes.splash), isNull);
    });

    test('sem login: Login, Cadastro e Esqueci a senha ficam; o resto vai ao Login', () {
      for (final open in AppRoutes.signedOutLocations) {
        expect(
          entryRedirect(EntryStatus.signedOut, open),
          isNull,
          reason: open,
        );
      }
      expect(
        entryRedirect(EntryStatus.signedOut, AppRoutes.home),
        AppRoutes.login,
      );
      expect(
        entryRedirect(EntryStatus.signedOut, AppRoutes.splash),
        AppRoutes.login,
      );
    });

    test('etapas obrigatórias levam à própria tela', () {
      expect(
        entryRedirect(EntryStatus.verifyEmail, AppRoutes.home),
        AppRoutes.verifyEmail,
      );
      expect(
        entryRedirect(EntryStatus.completeProfile, AppRoutes.plans),
        AppRoutes.googleFirstAccess,
      );
      expect(
        entryRedirect(EntryStatus.tutorial, AppRoutes.login),
        AppRoutes.welcome,
      );
      expect(entryRedirect(EntryStatus.tutorial, AppRoutes.welcome), isNull);
    });

    test('pronto: telas de entrada vão ao Início; as do app ficam', () {
      for (final entry in AppRoutes.entryLocations) {
        expect(
          entryRedirect(EntryStatus.ready, entry),
          AppRoutes.home,
          reason: entry,
        );
      }
      for (final tab in [
        AppRoutes.home,
        AppRoutes.tasks,
        AppRoutes.plans,
        AppRoutes.calendar,
        AppRoutes.profile,
      ]) {
        expect(entryRedirect(EntryStatus.ready, tab), isNull, reason: tab);
      }
    });
  });
}
