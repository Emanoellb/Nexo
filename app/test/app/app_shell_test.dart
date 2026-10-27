import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexo/app/nexo_app.dart';
import 'package:nexo/features/auth/application/auth_providers.dart';
import 'package:nexo/features/auth/data/fake_auth_repository.dart';
import 'package:nexo/features/auth/domain/auth_user.dart';

void main() {
  testWidgets('usuário pronto abre no Início e navega pelas abas', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: NexoApp()));
    await tester.pumpAndSettle();

    expect(find.text('Em construção · bloco 6 · Início'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.target));
    await tester.pumpAndSettle();
    expect(find.text('Em construção · bloco 3 · Planos'), findsOneWidget);
    // O nome aparece na aba selecionada e no título da página.
    expect(find.text('Planos'), findsNWidgets(2));
  });

  testWidgets('sem login vai ao Login; ao entrar, vai ao Início', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const NexoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Em construção · bloco 12 · fluxo de entrada'),
      findsOneWidget,
    );
    expect(find.text('Entrar'), findsOneWidget);

    auth.setUser(FakeAuthRepository.prototypeUser);
    await tester.pumpAndSettle();
    expect(find.text('Em construção · bloco 6 · Início'), findsOneWidget);
  });

  testWidgets('e-mail não verificado vai à tela de verificação', (
    tester,
  ) async {
    final auth = FakeAuthRepository(
      initialUser: const AuthUser(uid: 'u2', emailVerified: false),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const NexoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Verifique seu e-mail'), findsOneWidget);
  });

  testWidgets('Google sem perfil vai ao primeiro acesso; tutorial depois', (
    tester,
  ) async {
    const user = AuthUser(
      uid: 'g1',
      emailVerified: true,
      signedInWithGoogle: true,
    );
    final auth = FakeAuthRepository(initialUser: user);
    final profiles = FakeUserProfileRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userProfileRepositoryProvider.overrideWithValue(profiles),
        ],
        child: const NexoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Primeiro acesso'), findsOneWidget);

    profiles.setProfile(user.uid, const UserProfile(displayName: 'Ana'));
    await tester.pumpAndSettle();
    expect(find.text('Boas-vindas'), findsOneWidget);
  });
}
