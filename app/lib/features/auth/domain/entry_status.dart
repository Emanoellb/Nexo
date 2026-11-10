import 'auth_user.dart';

/// Em que ponto da entrada o usuário está. Decide para onde o roteador leva.
enum EntryStatus {
  /// Auth ou perfil ainda carregando: fica na Splash.
  loading,

  /// Sem login: Login, Cadastro ou Esqueci minha senha.
  signedOut,

  /// Conta de e-mail e senha sem verificação: tela 05.
  verifyEmail,

  /// Login Google sem `users/{uid}`: tela 03b (idade e aceite).
  completeProfile,

  /// Tutorial ainda não visto (`tutorialSeen`): tela 06.
  tutorial,

  /// Excluir conta em andamento (`deletionRequestedAt`): Perfil 09,
  /// "Excluindo sua conta…". Também no login seguinte, se o app fechou no
  /// meio.
  deleting,

  /// Pronto para usar o app.
  ready,
}

/// Função pura: o status a partir do auth e do perfil.
///
/// [profileLoading] só importa quando há usuário verificado.
EntryStatus resolveEntryStatus({
  required bool authLoading,
  required AuthUser? user,
  required bool profileLoading,
  required UserProfile? profile,
  bool deletionRunning = false,
}) {
  if (authLoading) return EntryStatus.loading;
  if (user == null) return EntryStatus.signedOut;
  if (deletionRunning) return EntryStatus.deleting;
  if (!user.emailVerified) return EntryStatus.verifyEmail;
  if (profileLoading) return EntryStatus.loading;
  if (profile == null) return EntryStatus.completeProfile;
  if (profile.deletionRequestedAt != null) return EntryStatus.deleting;
  if (!profile.tutorialSeen) return EntryStatus.tutorial;
  return EntryStatus.ready;
}
