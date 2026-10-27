import '../../features/auth/domain/entry_status.dart';
import 'routes.dart';

/// Função pura do redirecionamento de entrada. Devolve o caminho para onde
/// ir, ou `null` para ficar onde está.
///
/// [splashFinished]: enquanto a animação da splash não termina, o app fica
/// nela, qualquer que seja o status.
String? entryRedirect(
  EntryStatus status,
  String location, {
  bool splashFinished = true,
}) {
  String? goTo(String target) => location == target ? null : target;

  if (!splashFinished) return goTo(AppRoutes.splash);

  switch (status) {
    case EntryStatus.loading:
      return goTo(AppRoutes.splash);
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
