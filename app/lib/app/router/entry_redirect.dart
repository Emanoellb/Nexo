import '../../features/auth/domain/entry_status.dart';
import 'routes.dart';

/// Função pura do redirecionamento de entrada. Devolve o caminho para onde
/// ir, ou `null` para ficar onde está.
///
/// [splashFinished]: enquanto a animação da splash não termina, o app fica
/// nela, qualquer que seja o status. Depois dela, `loading` mantém a tela
/// atual.
String? entryRedirect(
  EntryStatus status,
  String location, {
  bool splashFinished = true,
}) {
  String? goTo(String target) => location == target ? null : target;

  if (!splashFinished) return goTo(AppRoutes.splash);
  if (AppRoutes.anytimeLocations.contains(location)) return null;

  switch (status) {
    case EntryStatus.loading:
      // A splash já terminou (ex.: perfil recarregando no login): fica onde
      // está até o status se resolver, sem repetir a splash.
      return null;
    case EntryStatus.signedOut:
      return AppRoutes.signedOutLocations.contains(location)
          ? null
          : AppRoutes.login;
    case EntryStatus.verifyEmail:
      return goTo(AppRoutes.verifyEmail);
    case EntryStatus.completeProfile:
      return goTo(AppRoutes.googleFirstAccess);
    case EntryStatus.tutorial:
      return goTo(AppRoutes.welcome);
    case EntryStatus.ready:
      return AppRoutes.entryLocations.contains(location)
          ? AppRoutes.home
          : null;
  }
}
