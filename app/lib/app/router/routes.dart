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

  /// Detalhe aberto dentro de uma aba (disciplina, plano, objetivo): a tela
  /// tem a própria barra de topo.
  static bool isTabDetail(String path) =>
      isSubjectDetail(path) ||
      path.startsWith('$plans/plan/') ||
      path.startsWith('$plans/goal/');

  /// Nova tarefa e detalhe da tarefa, por cima das abas.
  static const newTask = '/new-task';
  static const taskDetail = '/task/:id';
  static String taskDetailOf(String id) => '/task/$id';

  /// Detalhe do plano e do objetivo, dentro da aba Planos (a barra
  /// continua).
  static const planDetailSegment = 'plan/:id';
  static String planDetailOf(String id) => '$plans/plan/$id';
  static const goalDetailSegment = 'goal/:id';
  static String goalDetailOf(String id) => '$plans/goal/$id';

  /// Criar plano (3 passos) e Editar plano, em tela cheia por cima das
  /// abas. [newPlanPrimary]: o criado vira o principal ("Criar plano" no
  /// cartão do plano encerrado).
  static const newPlan = '/new-plan';
  static const newPlanPrimary = '/new-plan?primary=1';
  static const editPlan = '/edit-plan/:id';
  static String editPlanOf(String id) => '/edit-plan/$id';

  /// Telas do Foco, que entram na branch dele: "Em construção" por
  /// enquanto (destinos provisórios da aba Sessões do plano).
  static const logHours = '/log-hours';
  static const editSession = '/edit-session';

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
