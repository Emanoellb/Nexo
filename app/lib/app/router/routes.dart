/// Caminhos do app. Identificadores internos em inglês; a interface é pt-BR.
abstract final class AppRoutes {
  // Entrada (telas no bloco do fluxo de entrada).
  static const splash = '/splash';
  static const login = '/login';
  static const forgotPassword = '/login/forgot-password';
  static const signUp = '/sign-up';
  static const googleFirstAccess = '/sign-up/google';
  static const verifyEmail = '/verify-email';
  static const welcome = '/welcome';

  // Documentos legais, abertos pelos links do aceite.
  static const terms = '/legal/terms';
  static const privacy = '/legal/privacy';

  // Abas da barra de navegação. `calendar` aparece como "Agenda".
  static const home = '/home';
  static const tasks = '/tasks';
  static const plans = '/plans';
  static const calendar = '/calendar';

  /// Detalhe da disciplina, dentro da aba Tarefas (a barra continua):
  /// [subjectDetailSegment] é a rota filha de [tasks].
  static const subjectDetailSegment = 'subject/:id';
  static String subjectDetailOf(String id) => '$tasks/subject/$id';
  static bool isSubjectDetail(String path) =>
      path.startsWith('$tasks/subject/');

  /// Telas ainda sem design (decisão do usuário, 05/11/2026): abrem
  /// "Em construção" por cima das abas.
  static const newTask = '/new-task';
  static const taskDetail = '/task/:id';
  static String taskDetailOf(String id) => '/task/$id';

  /// Fora da barra desde 04/11/2026 (vai para o avatar no topo das abas).
  static const profile = '/profile';

  /// Telas que só fazem sentido antes de o usuário estar pronto.
  static const entryLocations = {
    splash,
    login,
    forgotPassword,
    signUp,
    googleFirstAccess,
    verifyEmail,
    welcome,
  };

  /// Telas abertas sem login.
  static const signedOutLocations = {login, forgotPassword, signUp};

  /// Abertas em qualquer etapa (o aceite fica no Cadastro e na 03b).
  static const anytimeLocations = {terms, privacy};
}
