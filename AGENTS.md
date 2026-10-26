# AGENTS.md · Nexo

Guia para qualquer agente de IA (Claude, Codex, Copilot, Gemini, Cursor…) trabalhar no Nexo sem inventar nada.
Estado descrito: **25/10/2026**. Idioma do projeto: **português (pt-BR)**, inclusive na UI, na documentação e nas respostas.

---

## 0. Regras para não alucinar (leia primeiro)

1. **Este arquivo resume; as fontes detalhadas mandam.** Em caso de dúvida, abra o documento apontado na seção 13. Se este arquivo e uma fonte divergirem, **não escolha sozinho**: aponte a divergência com o trecho de cada lado e pergunte ao usuário.
2. **Confirmado × suposição.** Diga sempre o que você verificou (arquivo, linha, comando) e o que está supondo. Comportamento do Firebase, do Flutter ou de terceiros que você não conferiu na documentação oficial é **"não confirmado"**. As docs do projeto usam a legenda **[C]** confirmado, **[NC]** não confirmado e **[D]** decisão do usuário.
3. **Não invente decisões.** Se algo não está decidido aqui nem nas fontes, pergunte. Exemplos do que NÃO existe ainda: rotas definitivas, telas fora do fluxo de entrada no código, Cloud Functions, iOS.
4. **Decisões mudam; vale a mais recente com data.** Algumas notas antigas citam Apple, FCM e Cloud Functions no MVP: isso foi **substituído** (seção 4).
5. **Escopo estrito.** Faça só o que foi pedido. Refatoração ou ampliação de escopo exige aprovação antes.
6. **Fases separadas:** auditoria (somente leitura) → plano → implementação → execução. Não edite durante uma auditoria.
7. **Nada que altere dados reais sem autorização explícita:** deploy de regras, console do Firebase, apagar dados, publicar. O projeto Firebase é **único** (testes e usuários reais dividem o mesmo banco).

---

## 1. Produto

**Nexo** é um app de organização pessoal e produtividade. Ele liga **objetivos → planos de ação → tarefas, disciplinas e entregas → calendário → sessões de foco → progresso**. O usuário transforma um objetivo de médio ou longo prazo num plano executável e define quanto vai se dedicar. Depois, acompanha o que fazer em cada dia e registra o tempo realmente investido. O app calcula sozinho:
- progresso;
- horas planejadas × realizadas;
- consistência, dias cumpridos e sequências;
- pontos e nível.

- **Público:** estudantes universitários e técnicos e jovens profissionais. Não pode parecer infantil nem "só da escola".
- **Pergunta que o app responde:** "O que eu preciso fazer, quando, e no que devo focar agora?"
- **Princípio-filtro:** "O Nexo deve reduzir a sensação de desorganização, não adicionar mais uma ferramenta para o usuário administrar." Poucos elementos, hierarquia forte, cor controlada, navegação simples.
- **Gamificação leve:** pontos, nível e poucas medalhas. Sem moedas, ranking ou animações explosivas. A moeda única é **pontos** (nunca "XP").
- **Idade mínima: 16 anos.**

---

## 2. Estado atual (25/10/2026)

| Área | Situação |
|---|---|
| Design system (`pen.dev/nexo.lib.pen`) | Pronto: tokens, cerca de 60 componentes, todos com `context`, e a logo como componentes `Brand/Logo/*` |
| Protótipo (`pen.dev/nexo.app.pen`) | Só o **fluxo de entrada**: Splash, Login, Cadastro, 03b Primeiro acesso com Google, Esqueci minha senha, Verifique seu e-mail, Boas-vindas + tutorial de 5 passos. As demais telas **não foram desenhadas** |
| Marca (`pen.dev/nexo.brand.pen`, `app/assets/brand/`) | Logo definida em 21/10/2026. Falta a busca no INPI |
| App Flutter (`app/`) | Tema gerado dos tokens e componentes base (`lib/core/ui`) com testes e goldens. **Nenhuma tela de produto, nenhuma rota e nenhum fluxo de auth implementados**: o `main.dart` mostra só um placeholder |
| Firebase | Configuração do MVP concluída: Auth, Firestore com regras v0.6 e índices publicados, backups e Crashlytics. Falta o teste no aparelho, que depende do auth no app |
| Documentos legais (`app/docs/legal/`) | Rascunhos **v0.2** dos Termos e da Política. **Precisam de revisão jurídica antes de publicar** |
| Git | Repositório na raiz, branch `main`, **ainda sem nenhum commit** |

Modo de trabalho decidido em 24/10/2026: um assunto por vez. A configuração do Firebase foi concluída antes de o Flutter e o design voltarem. As mudanças pendentes para o app estão em `app/docs/backend/firebase-setup.md` §11 e `app/docs/backend/firestore-rules.md` §7.

---

## 3. Estrutura do repositório

```
D:\Dev\Nexo\
├── AGENTS.md / CLAUDE.md     guias para agentes
├── .gitignore                lista branca: só app/, AGENTS.md, CLAUDE.md, README.md e .github/ entram no git
├── pen.dev/                  design (FORA do git)
│   ├── nexo.lib.pen          design system (biblioteca)
│   ├── nexo.app.pen          telas do app (importa a lib)
│   ├── nexo.brand.pen        exploração e pacote da logo
│   └── *.png                 imagens de referência (benchmark de onboarding, não fazem parte do produto)
└── app/                      projeto Flutter
    ├── lib/
    │   ├── main.dart             Firebase.initializeApp + Crashlytics; home provisória
    │   ├── firebase_options.dart gerado pelo flutterfire (só Android)
    │   └── core/
    │       ├── theme/            nexo_colors, nexo_dimensions, nexo_typography, nexo_theme
    │       └── ui/               componentes base (brand, buttons, feedback, foundation, inputs, navigation, selection) + ui.dart
    ├── test/                     testes de widget, goldens (tag `golden`) e helpers
    ├── assets/                   brand/ (logo, ícones, favicons), fonts/ (Manrope variável), icons/ (google-g.svg)
    ├── docs/                     documentação do projeto (seção 13)
    ├── firestore.rules           regras publicadas (fonte da verdade depois do deploy)
    ├── firestore.indexes.json    3 índices compostos
    ├── firestore_tests/          testes das regras (Node; rodam só no emulador)
    └── firebase.json             FlutterFire + caminhos de rules/indexes
```

- A documentação fica em **`app/docs/`**. Não existem pastas `.docs/` nem `Docs/`.
- `.pen` são arquivos do Pencil (pen.dev). Leia e escreva **só pelas ferramentas do Pencil (MCP)**, nunca editando o arquivo à mão.

---

## 4. Decisões vigentes

### Plataforma e Firebase (`app/docs/backend/firebase-setup.md` §0)

| # | Decisão | Data |
|---|---|---|
| F1 | Pacote Android `dev.emanoelbarbosa.nexo`. **Não muda depois de publicar** | 22/10/2026 |
| F2 | **Um projeto Firebase só**: `nexo-app-gestao-f97bb`. Risco aceito, a rever antes do lançamento público | 21/10/2026 |
| F3 | Firestore em `southamerica-east1` (permanente) | 21/10/2026 |
| F4 | Plano Blaze | 21/10/2026 |
| F5 | App Check **depois** do MVP | 21/10/2026 |
| F6 | **Só Android** no MVP. A pasta `ios/` existe, mas está fora do escopo | 21/10/2026 |
| F7 | **Nada da Apple**: sem Sign in with Apple. Login = **e-mail/senha + Google** | 21/10/2026 |

### Produto, dados e legal

| # | Decisão |
|---|---|
| D1 | Idade mínima 16 anos, conferida pela **data de nascimento** (`birthDate`), que o app não altera depois |
| D2 | Telemetria: **só Crashlytics**. **Sem Google Analytics**: não instale `firebase_analytics` |
| D3 | Controlador dos dados: pessoa física, por enquanto |
| D4 | Disciplinas e entregas entram no MVP |
| — | **Sem Cloud Functions no MVP**: o app calcula e grava dias, pontos, nível e conquistas (24/10/2026). Evolução futura: levar os pontos para o servidor |
| — | **Notificações locais** (agendadas no aparelho). Sem FCM, sem tokens e sem `devices`/`notificationLog` no Firestore (24/10/2026) |
| — | E-mail verificado é exigido para usar os dados. Contas Google já chegam verificadas |
| — | Redefinição de senha na **página padrão do Firebase**, com o texto padrão em pt-BR (o console bloqueou a edição do template; 25/10/2026) |
| — | Sem domínio próprio de envio no MVP: o remetente é `noreply@nexo-app-gestao-f97bb.firebaseapp.com` |
| — | Backups diários com retenção de 7 dias. Relatórios do Crashlytics: 90 dias |
| — | MVP **gratuito** |
| — | Tema **só claro** por enquanto, com estrutura pronta para o dark (seção 6) |

### Arquitetura Flutter (decidida, ainda não implementada no código)

- **Riverpod** (`flutter_riverpod`, sem geração de código): injeção de dependência e estado global (repositórios, sessão de auth, refresh do roteador).
- **Cubit** (`flutter_bloc`): estado de cada tela.
- **go_router** para navegação. As rotas ainda não estão definidas.
- Auth atrás de uma interface `AuthRepository`. Hoje não existe implementação no código; a real (`FirebaseAuthRepository`) é a pendência A1.
- Os três pacotes já estão no `pubspec.yaml`, mas **ainda não são usados** em `lib/`. Antes de estruturar features, confirme com o usuário a organização de pastas.

---

## 5. Regras de negócio essenciais

Fonte: `app/docs/backend/firestore-rules.md` §3–§5 e §7. O que as regras do Firestore não conseguem validar é **responsabilidade do app** (§6 daquela doc).

- **Dados do usuário sob `users/{uid}`**: sem leitura entre usuários. Coleções: `users`, `plans` (com `scheduleVersions`, `topics`, `sessions`, `days`), `tasks`, `subjects`, `goals`, `achievements`. Conteúdo do app, carregado pelo console: `legalDocuments` (leitura pública) e `achievementsCatalog` (9 medalhas).
- **Lista branca de campos**: campo fora do contrato é negado. Use exatamente os nomes da §4 da doc de regras.
- **Carimbos do servidor** (`FieldValue.serverTimestamp()`): `createdAt`, `updatedAt`, `consents.acceptedAt`, `completedAt`, `finalizedAt`, `earnedAt`, `deletionRequestedAt`.
- **Inteiros**: `dailyGoalMinutes`, `durationSeconds`, `doneMinutes`, `reminderMinutesBefore`, `overloadThreshold`, `points`.
- **Cadastro**:
  - criar `users/{uid}` com `displayName`, `birthDate`, `timeZone` e `consents` (`termsVersion`, `privacyVersion`, `acceptedAt`), com as versões lidas de `legalDocuments/current`;
  - depois do "Já confirmei", chamar `reload()` + `getIdToken(true)`.
- **Login Google com menos de 16 anos**: o app apaga na hora a conta recém-criada no Auth (`currentUser.delete()`) e volta ao Login.
- **Sessão de foco**:
  - o cronômetro roda no aparelho e a sessão só vai ao Firestore ao encerrar;
  - a sessão é dividida à meia-noite, no fuso do usuário;
  - cada sessão é ligada a um **tópico do plano** (`topicId`).
- **Janela de 7 dias** para criar ou editar sessões e dias. A semana vai de **domingo a sábado**.
- **Pontos**:
  - tarefa concluída +1 (reabrir −1); dia do plano 5/3/7/0;
  - **nível = pontos ÷ 20 (parte inteira) + 1**.
- **Avisos**:
  - aviso noturno fixo às **21h** se a meta do dia não estiver completa;
  - aviso de entrega da tarefa: 1 h, 1 dia, 1 semana ou personalizado;
  - no máximo 1 aviso por plano por dia.
- **Situação da entrega** (tarefa): Não iniciada, Em andamento, Entregue, Aguardando correção.
- **Excluir conta e excluir plano são feitos pelo app**:
  - excluir conta pede login de novo, apaga tudo e, por fim, a conta do Auth;
  - excluir plano marca `status: "deleting"` e apaga as subcoleções em lotes;
  - se o app fechar no meio, retoma no próximo login.

---

## 6. Design system

- **Fonte da verdade:** `pen.dev/nexo.lib.pen`. Mapeamento para Flutter: `app/docs/frontend/tokens-flutter.md`.
- **Cores:** componentes e telas usam **só `Colors/Semantic/*`**. Nunca use primitivas nem cor literal (hex). No Flutter, as cores vêm de `Theme.of(context).colorScheme` ou `context.nexoColors`.
- **Dark mode (futuro):** criar `NexoColors.dark`/`NexoElevation.dark` e preencher os mesmos papéis semânticos. Nenhum widget muda. Ainda não existe eixo de tema na lib.
- **Tipografia:** Manrope (variável, empacotada em `assets/fonts/`). Use os estilos do tema: um `copyWith(fontWeight:)` não ajusta o eixo `wght`.
- **Espaço, forma, sombra e movimento:** `context.spacing`, `context.shape`, `context.elevation`, `context.motion`. Nada de valores soltos.
- **Ícones:** Lucide (`lucide_icons_flutter`), tamanhos 24, 20 e 16. Confira o nome do glifo, porque os nomes mudam entre versões.
- **Logo:** use os componentes e o widget de logo do projeto (`core/ui/brand`) e os SVG de `assets/brand/logo/svg/`. Nunca desenhe ou recrie a logo. Regras de uso em `app/assets/brand/README.md`.
- **Decisões travadas pelo usuário:**
  - Snackbar **clara**, na **parte de baixo**, acima da barra de navegação. Não proponha topo nem versão escura.
  - Superfícies claras e neutras: evite superfícies escuras ou invertidas.
  - Criação de itens no topo ("+ Nova tarefa" / "+ Novo plano"). FAB só onde não há o botão central "Planos".
  - Escada de intrusão: elemento → skeleton/progresso → alert → snackbar → dialog. Prefira "Desfazer" a confirmação, exceto em exclusão permanente.
  - A cor Secondary é só para progresso e conquistas.
- **Acessibilidade:** alvo de toque ≥ 48 px, contraste WCAG AA, foco visível, `Semantics` em controles sem texto. A cor nunca é o único sinal.
- **Textos de exemplo:** use **sempre nomes de instituições fictícios** (ex.: "Concurso Banco Horizonte"), nunca bancos, universidades, escolas, concursos ou empresas reais.

---

## 7. Firebase: operação

- **Projeto:** `nexo-app-gestao-f97bb` · app Android `1:956300519140:android:7792abfff1061daa6b6ef1`.
- **Credenciais:**
  - login e chaves ficam só com o usuário;
  - nunca coloque segredos no código, no git ou na conversa;
  - `key.properties`, keystores e service accounts ficam fora do git (`app/.gitignore`).
- **Emulador:** **não** use o Firebase Emulator no dia a dia. A única exceção é rodar os testes de `firestore_tests/` **uma vez antes de cada deploy das regras**. Ao terminar, confira a porta 8080 e encerre o processo Java do emulador: no Windows ele costuma ficar aberto. Os testes de uso são em **aparelho físico Android**.
- **Deploy das regras:** só com autorização explícita do usuário, a partir de `app/`. A CLI sobrescreve as regras do console.
- **SHA de release:** hoje só os SHA de debug estão cadastrados. Ao criar a keystore de upload ou o app no Play Console, **avise o usuário** para cadastrar os SHA de release e rodar o `flutterfire configure` de novo. Sem isso, o login Google falha para quem instala pela Play Store.
- **Restrição das API keys:** depois do primeiro teste no aparelho com login.

---

## 8. Comandos

Rode a partir de `D:\Dev\Nexo\app`. Explique antes de rodar qualquer coisa que instale, baixe, gere arquivos ou fique rodando em segundo plano.

| Objetivo | Comando |
|---|---|
| Dependências | `flutter pub get` |
| Análise estática | `flutter analyze` |
| Testes (todos) | `flutter test` |
| Testes sem goldens | `flutter test --exclude-tags golden` |
| Atualizar goldens (gerados no Windows) | `flutter test --update-goldens test/goldens` |
| Build de debug | `flutter build apk --debug` |
| Testes das regras (só antes de deploy) | `npm --prefix firestore_tests ci` e depois `firebase emulators:exec --only firestore --project demo-nexo "npm --prefix firestore_tests test"` |
| Deploy das regras (**só com autorização**) | `firebase deploy --only firestore:rules --project nexo-app-gestao-f97bb` |

Versões de referência: Dart SDK `^3.13.2`, AGP 9.1.0, Kotlin 2.4.0, minSdk 24 (exigido por `firebase_core` 5 / `firebase_auth` 7), JVM 17.

---

## 9. Convenções

- **UI e textos em pt-BR**, com voz ativa e botões com ação específica ("Criar conta", nunca "OK"/"Enviar"). Mensagens de erro dizem o que houve e o que fazer.
- **Terminologia:** a mudança de termo altera só o texto exibido, por padrão. Nomes persistidos (campos do Firestore), contratos e testes só mudam com aprovação.
- **Commits e PRs:**
  - Conventional Commits, só quando o usuário pedir;
  - PRs com `Fixes #<número-real-da-issue>`;
  - títulos e descrições de PR podem ser pedidos em inglês.
- **Relatório de validação separado por tipo:** análise estática, testes automatizados, build, dispositivo, deploy. Nunca diga "validado" de forma genérica. Se algo não rodou, diga exatamente isso.
- **Dados pessoais:** não imprima dados pessoais completos em logs, testes ou respostas. Os relatórios do Crashlytics não podem conter e-mail, nome nem texto livre.

---

## 10. Não faça

- Não instale `firebase_analytics`, nem SDK de anúncios ou de identificador de publicidade.
- Não adicione Sign in with Apple, nem nada de iOS ao escopo do MVP.
- Não crie Cloud Functions, FCM ou coleções fora do contrato das regras sem decisão nova do usuário.
- Não use cor literal ou primitiva em widgets ou telas, e não desenhe logo.
- Não use nomes de instituições reais.
- Não rode deploy, não mexa no console e não apague dados sem autorização explícita.
- Não suba o emulador fora da janela de deploy das regras.
- Não edite `.pen` à mão.
- Não edite este `AGENTS.md` como parte de outra tarefa: proponha o diff ao usuário.

---

## 11. Pendências abertas (principais)

- **App:** pendências A1–A8 em `firebase-setup.md` §11.2 (auth real, login Google, gravações no Firestore, keystore de release, crash de teste) e a lista de `firestore-rules.md` §7.
- **Design:** telas além do fluxo de entrada (Plano de ação, Início, Tarefas, Calendário, Objetivos, Perfil com "Excluir conta"), paleta de cores das disciplinas e as 9 medalhas. Lista em `firestore-rules.md` §7 e `docs/legal/pendencias.md` §C.
- **Legal:** revisão jurídica antes de publicar. Vigência prevista para 01/11/2026. Também falta o link web para pedir exclusão da conta, exigido pelo Google Play (`pendencias.md` §A e §D).
- **Marca:** busca de anterioridade e registro no INPI.

---

## 12. Divergências conhecidas (não resolva sozinho)

- `ca7IW` (frame de regras do Plano de ação, na lib) ainda cita Cloud Function para fechar os dias e FCM para avisos. **Vale a decisão de 24/10/2026: tudo no app, com notificações locais.**
- `ca7IW` cita o caminho `plans/{planId}/sessions`. **Vale `users/{uid}/plans/{planId}/sessions`.**
- O componente `Nexo/Achievement` diz "≤ 8 medalhas". **Valem 9**, sem "Semana em dia".
- O root `.gitignore` tem a linha `!.env`, que faria um `.env` na raiz entrar no git. Isso foi apontado ao usuário e ainda não foi decidido.

---

## 13. Onde está cada verdade

| Assunto | Documento |
|---|---|
| Configuração do Firebase, decisões F1–F7, pendências do app | `app/docs/backend/firebase-setup.md` |
| Regras do Firestore, contrato de campos, regras de negócio, roteiro | `app/docs/backend/firestore-rules.md` + `app/firestore.rules` |
| Esqueci minha senha (fluxo, erros, mensagens) | `app/docs/backend/auth-redefinicao-senha.md` |
| Tokens → Flutter | `app/docs/frontend/tokens-flutter.md` |
| Dados pessoais tratados | `app/docs/legal/inventario-dados-mvp.md` |
| Termos e Política (rascunhos v0.2) | `app/docs/legal/termos-de-uso.md`, `politica-de-privacidade.md` |
| Pendências legais e decisões do usuário | `app/docs/legal/pendencias.md` |
| Marca e uso da logo | `app/assets/brand/README.md` |
| Design system e telas | `pen.dev/nexo.lib.pen`, `pen.dev/nexo.app.pen` (pelo MCP do Pencil). O campo `context` de cada componente e tela descreve comportamento e o widget Flutter equivalente |
