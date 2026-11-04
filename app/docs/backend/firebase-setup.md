# Nexo · Configuração do Firebase e ligação com o app Flutter

Status: **v1.0, aprovada pelo usuário em 21/10/2026** · Sessão: nexo-firebase-setup
Escopo: passo a passo de configuração do MVP (**só Android, sem nada da Apple**). Esta sessão não altera o projeto Firebase nem os arquivos de `app/`: os passos no console são do usuário; o código é da sessão nexo-flutter.
Base: `docs/legal/inventario-dados-mvp.md`, `docs/legal/pendencias.md`, `docs/backend/auth-redefinicao-senha.md` (v1.0).

**Estado em 22/10/2026:**
- **Passos 1 a 4 concluídos:**
  - console configurado pelo usuário;
  - app Android ligado: o `firebase_options.dart` e o `firebase.json` estão só com Android;
  - SHA-1 e SHA-256 de debug cadastrados;
  - `flutter analyze` sem problemas e `flutter build apk --debug` concluído.
- **Pendentes:**
  - teste no aparelho físico (login por e-mail e Google, crash de teste);
  - ~~regras do Firestore~~ **publicadas em 24/10/2026** (v0.5) e atualizadas em 25/10/2026 (v0.6 + 3 índices compostos); ver `docs/backend/firestore-rules.md`;
  - SHA de release;
  - restrição das API keys (5.2).
- O projeto Flutter atual é mantido; recriar do zero foi descartado.

Legenda: **[C]** confirmado na documentação oficial (URLs na seção 13) · **[NC]** não confirmado, testar no projeto · **[D]** decisão ou recomendação.

Quem faz cada passo:
- **Você (máquina)**: instalação global, uma vez por computador. Não muda o repositório.
- **Você (console)**: Firebase ou Google Cloud. Login e chaves só com você; nenhum segredo passa por sessão do Claude.
- **nexo-flutter**: mudanças no código em `D:\Dev\Nexo\app`. Combinar com a sessão antes de rodar qualquer comando que altere `app/`.

---

## 0. Decisões

| # | Tema | Decisão | Efeito |
|---|---|---|---|
| F1 | Nome do pacote Android (`applicationId`; no console: "Nome do pacote do Android") | **`dev.emanoelbarbosa.nexo`** (22/10/2026). App registrado no console pelo usuário: "App Nexo", App ID `1:956300519140:android:7792abfff1061daa6b6ef1` | A nexo-flutter troca o placeholder `com.example.nexo` no código. O `flutterfire configure` reaproveita o app já registrado [C] |
| F2 | Ambientes | ~~Um projeto só (21/10/2026)~~ **Decidido em 26/10/2026: separar desenvolvimento e produção agora**, em dois projetos Firebase. Motivos: dois revisores externos apontaram o projeto único como risco, e ainda não há usuários reais | Qual projeto fica com cada papel, os nomes e os IDs estão **em decisão** (seção 14). A doc oficial recomenda um projeto por ambiente [C]. O par pacote + SHA-1 é único entre projetos [C], por isso o app de desenvolvimento usa outro pacote (seção 14) |
| F3 | Região do Firestore | **`southamerica-east1`** (São Paulo, regional) | Permanente [C]. Preenche `[REGIÃO DO FIRESTORE]` na Política 7 |
| F4 | Plano | **Blaze, contratado** (21/10/2026) | Libera Cloud Functions, funções agendadas, backups e cotas maiores do Auth [C]. Fecha o R6 da spec de redefinição de senha |
| F5 | App Check | **Depois do MVP** | O passo 10 fica descrito, mas não é executado agora. A Política 3.5 precisa refletir isso |
| F6 | Plataforma do MVP | **Só Android** (21/10/2026) | Nada de iOS neste guia |
| F7 | Apple | **Nada da Apple no MVP** (21/10/2026) | Sem Sign in with Apple, sem Apple Developer Program e sem iOS. Login = **e-mail/senha + Google** |
| — | Herdadas | Sem Google Analytics (D2) · dados sob `users/{uid}` · reset na página padrão do Firebase (R1) | — |

**Identificadores do projeto:**

| Identificador | Valor | Onde aparece | Muda depois? |
|---|---|---|---|
| Nome do projeto | `nexo-app-gestao` | Só no console | Sim |
| Project ID | **`nexo-app-gestao-f97bb`** | Remetente `noreply@nexo-app-gestao-f97bb.firebaseapp.com` e domínios `.firebaseapp.com` / `.web.app` | **Não**: "After project creation, the project ID is permanent" [C, P1] |
| Nome do pacote Android / `applicationId` (F1) | **`dev.emanoelbarbosa.nexo`** | Google Play, aparelho (identifica o app instalado) e app registrado no Firebase. Não é o nome do projeto nem o nome exibido na loja | **Não** depois de publicar: o Play trata o envio como "a completely different app" [C, P2]. O app registrado no Firebase também não troca |

O placeholder `com.example.nexo` precisa sair do código antes do passo 4.

---

## 1. Pré-requisitos globais (você, máquina, uma vez)

Nada aqui muda o repositório.

| # | Passo | Comando | Propósito |
|---|---|---|---|
| 1.1 | Instalar **Node.js LTS 20 ou mais** (nodejs.org) | `node -v` | A Firebase CLI roda em Node. **Divergência:** a doc diz Node 18+ [C], o `package.json` atual da CLI exige 20+ [C]. Use 20 ou mais |
| 1.2 | Instalar a **Firebase CLI via npm** | `npm install -g firebase-tools` | Ler projetos, publicar regras, enviar símbolos do Crashlytics. Existe binário standalone [C], mas o README do FlutterFire CLI recomenda npm no Windows, porque o standalone "can cause problems" [C] |
| 1.3 | Conferir | `firebase --version` | Precisa de 11.9.0+ para o upload de símbolos do Crashlytics [C] |
| 1.4 | **Login (você, no navegador)** | `firebase login` | Abre uma página que volta para `localhost` [C]. Se o navegador não conseguir voltar, use `firebase login --no-localhost` [C] |
| 1.5 | Conferir a conta e o acesso | `firebase login:list` e `firebase projects:list` | Mostram a conta logada e os projetos visíveis [C] |
| 1.6 | Instalar o **FlutterFire CLI** | `dart pub global activate flutterfire_cli` | Registra o app e gera a configuração Flutter (versão atual 1.4.1 [C]) |
| 1.7 | Colocar o pub cache no **PATH** do Windows | Configurações › Sistema › Sobre › Configurações avançadas do sistema › Variáveis de ambiente › `Path` do usuário › adicionar a pasta `bin` do pub cache | O padrão é `%LOCALAPPDATA%\Pub\Cache\bin`, e o caminho "might vary" [C, dart.dev]. Se `PUB_CACHE` estiver definido, a pasta é `%PUB_CACHE%\bin`. Feche e abra o terminal depois |
| 1.8 | Conferir | `flutterfire --version` | Se aparecer "Could not find bin\flutterfire.dart", rode `dart pub global deactivate flutterfire_cli` e ative de novo (1.6) |
| 1.9 | Aceitar as licenças do Android | `flutter doctor --android-licenses` | Sem isso o build Android falha |
| 1.10 | Confirmar o `keytool` | `keytool -help` | Usado para ler o SHA-1/SHA-256 (passo 6.2). Vem com o JDK |

**Nunca:** `firebase login:ci`, token da CLI ou JSON de service account no repositório ou em mensagem para o Claude.

**Checklist 1**
- [ ] `node -v` mostra 20 ou mais.
- [ ] `firebase --version` responde.
- [ ] `firebase login:list` mostra a sua conta.
- [ ] `flutterfire --version` responde num terminal novo.
- [ ] `flutter doctor` sem erro de licença do Android.

---

## 2. Projeto no console (você)

O projeto já existe: nome `nexo-app-gestao`, Project ID `nexo-app-gestao-f97bb`, plano Blaze contratado (21/10/2026). Falta conferir:

1. **Google Analytics desligado** (D2). Configurações do projeto › Integrações: o Google Analytics não pode estar vinculado.
   - Se estiver, desvincule a propriedade. Os dados ficam na propriedade do Analytics [C]. O passo a passo exato no console é [NC].
2. **Orçamento com alertas** no Google Cloud Billing (ex.: 50%, 90% e 100% de um valor mensal baixo).
   - O orçamento **só avisa: não bloqueia o gasto** [C].
   - O teto de gasto (spend cap) não cobre Firestore nem Cloud Scheduler [C].
3. **Public-facing name** = `Nexo`.
   - Ele aparece nos e-mails que os usuários recebem e vira `%APP_NAME%` [C, P3].
   - Fica na página Settings do projeto [C]. O caminho exato do menu é [NC].
4. **Usuários e permissões:** só a sua conta como Owner. Papéis com o menor privilégio [C, security checklist].
   - Essa tela controla quem **administra o projeto** no console: desenvolvedores, gente de suporte.
   - Os usuários do app nunca aparecem ali: eles ficam em Authentication e não acessam o console.
   - Com uma pessoa só no projeto, basta conferir que a lista tem apenas a sua conta.

**Checklist 2**
- [ ] `firebase projects:list` mostra `nexo-app-gestao-f97bb`.
- [ ] Integrações: Google Analytics **não** vinculado.
- [ ] Uso e faturamento: plano Blaze.
- [ ] Orçamento criado, com o e-mail de alerta chegando para você.
- [ ] Public-facing name = `Nexo`.

---

## 3. Pacotes no app (nexo-flutter, antes do `flutterfire configure`)

O `flutterfire configure` só adiciona os plugins Gradle dos produtos que já estão no `pubspec.yaml` [C]. Por isso os pacotes entram **antes**. A lista completa de tarefas da nexo-flutter está na seção 11.

| Pacote | Versão de referência (21/10/2026) | Observação |
|---|---|---|
| `firebase_core` | 5.x | Exige `minSdk 24` [C] |
| `firebase_auth` | 7.x | Breaking: BoM 35, minSdk 24 [C]. Sem `dynamicLinkDomain` [C] |
| `cloud_firestore` | versão atual compatível com `firebase_core` 5 | [NC] versão exata |
| `firebase_crashlytics` | 6.x | Não depende de `firebase_analytics` [C] |
| `google_sign_in` | 7.x | API nova: `GoogleSignIn.instance.initialize(...)` e `authenticate()` [C] |
| ~~`firebase_analytics`~~ | **não instalar** | A doc do Crashlytics manda instalar [C], mas a decisão D2 exclui o Analytics |

---

## 4. Ligar o app Android com `flutterfire configure`

**Pré-condição:** a nexo-flutter já trocou `com.example.nexo` por `dev.emanoelbarbosa.nexo` no Android (`namespace` e `applicationId`). O app já está registrado no console (F1). Um app registrado no Firebase não troca o package name depois. O `google-services.json` não é baixado à mão: o comando abaixo gera esse arquivo.

**Quem roda:** você, no terminal, em `D:\Dev\Nexo\app`, combinado com a nexo-flutter, porque o comando altera arquivos de `app/`.

```bash
flutterfire configure --project=nexo-app-gestao-f97bb --platforms=android --android-package-name=dev.emanoelbarbosa.nexo
```

> **Sempre passe `--platforms=android`.** Sem essa opção, o comando pergunta as plataformas e pode registrar também um app iOS. Isso aconteceu em 22/10/2026: foi registrado o app "nexo (ios)" com `com.example.nexo`, e o `firebase_options.dart` e o `firebase.json` ganharam um bloco `ios`.
> Para corrigir:
> 1. Remova o app iOS no console (Configurações do projeto › Seus apps). Se a remoção pode ser desfeita: [NC].
> 2. Rode o comando acima de novo.
> 3. Confira que o bloco `ios` saiu do `firebase_options.dart`.
>
> **Se o configure falhar buscando o app removido** (`firebase apps:sdkconfig ios ... "Failed to get IOS app configuration"`), o `firebase.json` ainda aponta para o app iOS removido. Rode o comando com `--platforms=android` e responda **"yes"** quando ele perguntar se deve sobrescrever.
> Mesmo assim, confira o `firebase_options.dart`. Em 22/10/2026, o `firebase.json` foi regravado só com Android, mas o `firebase_options.dart` ficou com o bloco `ios` (arquivo gravado antes do `firebase.json`).

### 4.1 O que o comando faz

| Efeito | Detalhe | Status |
|---|---|---|
| Registra o app no console | Cria o app Android ou reaproveita um app já registrado | [C] |
| `lib/firebase_options.dart` | Identificadores "unique, but non-secret" | [C] |
| `android/app/google-services.json` | Configuração do app Android | [C] |
| `firebase.json` | O CLI registra ali cada configuração | [C]; local na raiz de `app/` [NC] |
| Gradle | Plugin `com.google.gms.google-services` e, com `firebase_crashlytics` no pubspec, `com.google.firebase.crashlytics`. Suporta Kotlin DSL (`.kts`) desde a 1.1.0 | [C]; compatibilidade com o **AGP 9.1** do projeto [NC]: a nexo-flutter revisa o diff e roda um build |

**Rodar de novo quando:**
- adicionar Google Sign-In ou Crashlytics [C];
- cadastrar SHA novo, para atualizar o `google-services.json` [C].

**Checklist 4**
- [ ] Console › Configurações do projeto › Seus apps: só **um** app Android, `dev.emanoelbarbosa.nexo`. O comando não pode criar um segundo app.
- [ ] `lib/firebase_options.dart`, `android/app/google-services.json` e `firebase.json` existem.
- [ ] `firebase_options.dart` e `firebase.json` **sem** bloco `ios`. `firebase apps:list --project nexo-app-gestao-f97bb` mostra só o app Android.
- [ ] O `git diff` em `app/android` mostra só os plugins esperados.
- [ ] `flutter build apk --debug` conclui (nexo-flutter).

---

## 5. Versionar a configuração e restringir as API keys

### 5.1 Versionar: recomendação [D]

**Versionar** `lib/firebase_options.dart`, `android/app/google-services.json` e `firebase.json`.

Por quê:
- A doc oficial diz que as API keys do Firebase são "Public by design" [C], e que é seguro incluí-las no código e nos arquivos de configuração, citando o `google-services.json` [C].
- Sem esses arquivos, um clone do repositório ou uma CI não compila.
- A proteção real vem das Security Rules, do App Check e das restrições das chaves [C], não de esconder os arquivos.
- A doc não diz literalmente "commite estes arquivos" [NC]: a recomendação é minha, com base no texto acima.

**Nunca versionar:**
- JSON de service account;
- keystore de release (`*.jks`, `*.keystore`) e `key.properties`;
- debug tokens do App Check [C];
- `firebase-debug.log`.

O `.gitignore` de `app/` precisa cobrir esses arquivos (tarefa da nexo-flutter). O `.gitignore` da raiz já é uma lista branca, só com `app/` e `docs/`.

### 5.2 Restringir as API keys [D, depois do app funcionar]

Onde: Google Cloud Console › APIs e serviços › Credenciais.

1. **Restrição por API:** as chaves criadas pelo Firebase já vêm restritas às APIs do Firebase [C]. Confira e **não remova** APIs exigidas pelo Firebase [C].
2. **Restrição por app:**
   - Restrinja a chave do Android a apps Android, com package + SHA-1. A combinação package + SHA-1 é [NC] na página do Firebase.
   - Inclua **todos** os SHA-1: debug, upload e Play App Signing. Senão o build de release para de funcionar.
3. Teste primeiro numa chave de teste: uma restrição de app pode impedir a chave de funcionar [C].
4. **Cota do Auth:** a checklist recomenda reduzir a cota padrão de `identitytoolkit.googleapis.com` para dificultar força bruta [C, security checklist]. **Decidido em 24/10/2026: não mexer no MVP.** Fica só a proteção automática de 100 contas novas por hora por IP [C]. Rever se o app crescer ou se houver sinal de abuso.

**Checklist 5**
- [ ] `git status` em `app/` não lista `.jks`, `key.properties` nem service account.
- [ ] Credenciais: cada chave com a restrição de API conferida.
- [ ] Depois das restrições de app: login e Firestore funcionam no build debug e no de release.

---

## 6. Authentication (você, console)

Comece em Authentication › **Get started**.

### 6.0 Configurações gerais

| Item | Onde | O que fazer | Status |
|---|---|---|---|
| Email enumeration protection | Authentication › Settings › User account management › User actions | Confirmar **ligada**. Já vem ligada em projetos criados a partir de 15/09/2023 | [C] |
| Uma conta por e-mail | Authentication › Settings | Manter o padrão. O Google, para e-mails @gmail.com, é provedor confiável e sobrescreve um e-mail/senha **não verificado** | [C], rótulo exato [NC] |
| Cota de cadastro | Authentication › Sign-in method | 100 contas por hora por IP. Não precisa mexer | [C] |
| Identity Platform | — | **Não fazer o upgrade no MVP.** Ele muda os limites (Spark: 3.000 DAU; Blaze: cobrança por MAU, 50.000 grátis) | [C] |

Efeitos no app (nexo-flutter), com a proteção ligada:
- O login errado volta como `invalid-credential`. `user-not-found` e `wrong-password` estão deprecated [C].
- `fetchSignInMethodsForEmail` foi removido no `firebase_auth` 6.0.0 [C].
- O cadastro continua com `email-already-in-use` [C].

### 6.1 E-mail/senha

1. Sign-in method › **Email/Password** › Enable › Save [C].
2. **Não** ligue "Email link (passwordless sign-in)": fora do MVP.
3. **Política de senha** (R5): **configurada pelo usuário em 22/10/2026.** Regra: mínimo de **8 caracteres**, com **maiúscula, minúscula, número e caractere especial**.
   - Fica em Authentication › Settings › Password policy [C].
   - O modo (Require ou Notify) não foi informado: confira se está em **Require** [D].
   - No app, `validatePassword` valida contra a política [C].
   - A tela 03 Cadastro precisa mostrar exatamente essa regra (design e nexo-flutter).

### 6.2 Google

1. Sign-in method › **Google** › Enable. Informe o e-mail de suporte do projeto [NC, rótulo exato].
2. **SHA-1 é obrigatório** no app Android [C].
   - Cadastre também o SHA-256 [D]: o App Check (Play Integrity) e os App Links exigem esse valor, e cadastrar não custa nada.
   - Se o Google Sign-In exige o SHA-256: [NC].
3. **Como obter o SHA** (você). Os valores não são segredo; o keystore e as senhas de release são.
   - Debug, no PowerShell: `keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore"`. Senha padrão: `android` [C].
   - Ou, em `D:\Dev\Nexo\app\android`: `.\gradlew signingReport`, que mostra SHA-1 e SHA-256 por variante [C].
   - Release: SHA da **chave de upload** (keystore que você cria) **e** da **chave de assinatura do Google Play** (Play Console › Release › Setup › App integrity) [C]. As duas são diferentes e as duas entram.
4. Console › Configurações do projeto › Seus apps › Android › **Add fingerprint** [C].
5. Rode o `flutterfire configure` de novo (ou baixe de novo o `google-services.json`). O arquivo passa a conter os OAuth clients [C].
   - Com o client web (`client_type: 3`) no arquivo, o app não precisa passar `serverClientId` no Dart [C].
6. Branding do botão: pendência D9 (advogado/design), fora deste guia.

### 6.3 Templates de e-mail em pt-BR

Authentication › **Templates**. Os textos aprovados estão em `auth-redefinicao-senha.md` §5.

| Template | O que editar | Status |
|---|---|---|
| Password reset | Nome do remetente `Nexo` · endereço `noreply@nexo-app-gestao-f97bb.firebaseapp.com` (R4) · reply-to `[E-MAIL DE CONTATO]` · assunto "Redefina sua senha do Nexo" · corpo da spec §5 (texto simples; HTML só se o editor aceitar) | [C] editável; HTML no editor [NC] |
| Email address verification | Nome do remetente, endereço, reply-to e assunto. Assunto sugerido: "Confirme seu e-mail no Nexo". O **corpo não é editável**; só o do reset é [C] | [D] assunto |
| Email address change | Remetente igual aos outros. Sem uso no MVP | [D] |

- **Bloqueio encontrado em 24/10/2026:** ao salvar o template Password reset, o console mostrou "As atualizações de modelos de e-mail não estão disponíveis para este projeto. Para receber ajuda com as mudanças no modelo, entre em contato com suporte do Firebase".
  - A causa não está confirmada na documentação oficial [NC]. Relatos da comunidade falam de uma restrição antiabuso do Firebase na edição de templates.
  - **Efeito:** até isso se resolver, os e-mails saem com o **texto padrão do Firebase**, no idioma de `setLanguageCode`. Não saem com o texto da spec §5 (R2 e R3).
  - O texto padrão em pt-BR ainda não foi visto [NC].
  - **Saídas:** (1) abrir um chamado no suporte do Firebase, com o Project ID e a mensagem exata (usuário); (2) aceitar o texto padrão no MVP, depois de conferir num teste que ele não promete prazo nem mostra "Olá, ." vazio.
  - **Decidido em 25/10/2026: saída (2).** O MVP usa o texto padrão; o chamado ao suporte fica para depois. Conferir o texto padrão no primeiro teste no aparelho.
  - Não recomendo SMTP próprio nem envio por Cloud Function no MVP.
- **Idioma:** o app chama `FirebaseAuth.instance.setLanguageCode('pt-BR')` antes de enviar [C]. O código exato aceito (`pt-BR` × `pt`) é [NC].
- A localização também pode ser definida "via the Firebase Console" [C]. O rótulo do menu de idioma é [NC].
- Os testes da spec §9 fecham os [NC]: prazo do link, HTML, `%DISPLAY_NAME%` e conta só Google.

### 6.4 Domínios autorizados

Authentication › Settings › **Authorized domains** [C].
- Servem para os fluxos web e de redirect do Auth [C]. O MVP só Android, com e-mail/senha e Google nativo, não depende dessa lista [D, inferência].
- Projetos criados depois de 28/04/2025 não incluem `localhost` [C]. Não precisa: o MVP não tem web.
- **Não adicionar nada no MVP** [D]. Só quando houver domínio próprio para o handler de ações (depois do MVP, opção B da spec).

### 6.5 Domínio de envio

1. **Sem domínio próprio no MVP** (R4, **decidido em 24/10/2026**): o remetente fica `noreply@nexo-app-gestao-f97bb.firebaseapp.com`, com o nome "Nexo". Fica como pendência para quando o projeto crescer.
2. **Domínio próprio, quando houver:**
   - Templates › lápis › "customize domain" › registros TXT e CNAME no DNS [C].
   - Espere até 24 h e clique em "Apply Custom Domain" [C].
   - Só pode haver **um** registro `v=spf1` por domínio [C].

### 6.6 Cotas de e-mail no Blaze (F4)

| E-mails por dia | Blaze |
|---|---|
| Verificação de e-mail | 100.000 |
| Redefinição de senha | 10.000 |
| Troca de e-mail | 10.000 |

Fonte: [C]. As cotas podem mudar sem aviso [C]. Com um projeto só (F2), os testes gastam a mesma cota.

**Checklist 6**
- [ ] Sign-in method: só Email/Password e Google **Enabled**; Email link **desligado**.
- [ ] Settings: enumeration protection marcada; política de senha conforme R5.
- [ ] App Android com SHA-1 e SHA-256 de debug (os de release, quando existirem).
- [ ] `google-services.json` atualizado depois dos SHA.
- [ ] Teste: login Google num build debug, no aparelho físico.
- [ ] Templates: remetente "Nexo", assunto e corpo do reset em pt-BR.
- [ ] Teste: um reset de senha chega em pt-BR numa conta de teste.

---

## 7. Cloud Firestore (você, console)

### 7.1 Criar o banco

1. Firestore Database › **Create database**.
2. **Edição: Standard.** É o padrão [C] e tem a cota gratuita documentada [C]. Se a cota gratuita vale para a Enterprise: [NC].
3. **Database ID:** deixe `(default)` [C]. É o único banco gratuito por projeto [C].
4. **Local:** `southamerica-east1` (regional) [C].
   - **Permanente** [C]: confira duas vezes antes de confirmar.
   - Hoje o local do banco `(default)` só amarra um futuro App Engine. Ele não amarra mais o Storage nem as funções de 2ª geração [C].
   - As Cloud Functions precisam declarar a própria região. Se `southamerica-east1` está disponível para Functions e Scheduler: [NC].
5. **Start in production mode**, que nega todo acesso de clientes [C]. **Não use o modo de teste**: ele permite que qualquer pessoa leia e sobrescreva os dados [C].

### 7.2 Regras: esqueleto bloqueado

> **Atualização de 24/10/2026: concluído.** As regras completas (v0.5) foram publicadas pela CLI e substituíram o bloqueio total abaixo. Contrato, decisões e testes: `docs/backend/firestore-rules.md`. O esqueleto e o mapa abaixo ficam como histórico.

Publique agora só o bloqueio total. As regras de verdade ficam com a **sessão de segurança**: ela cria o `firestore.rules` versionado e prepara o deploy pela CLI.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Tudo bloqueado até a sessão de segurança publicar as regras do MVP.
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

Mapa do inventário que a sessão de segurança vai preencher (só a estrutura; tudo continua `if false`):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Dados pessoais: tudo sob users/{uid} (inventário, princípio adotado).
    match /users/{uid} {
      allow read, write: if false; // TODO(segurança): dono = request.auth.uid == uid; validar campos (consentimentos, agregados só via Function)

      match /devices/{installationId}            { allow read, write: if false; } // TODO(segurança)
      match /goals/{goalId}                       { allow read, write: if false; } // TODO(segurança)
      match /plans/{planId} {
        allow read, write: if false;                                              // TODO(segurança)
        match /scheduleVersions/{versionId}       { allow read, write: if false; } // TODO(segurança)
        match /sessions/{sessionId}               { allow read, write: if false; } // TODO(segurança)
        match /days/{day}                         { allow read, write: if false; } // TODO(segurança): campos derivados só via Function
      }
      match /tasks/{taskId}                       { allow read, write: if false; } // TODO(segurança)
      match /subjects/{subjectId}                 { allow read, write: if false; } // TODO(segurança)
      match /achievements/{achievementId}         { allow read, write: if false; } // TODO(segurança): só via Function
      match /notificationLog/{logId}              { allow read, write: if false; } // TODO(segurança): só via Function
    }

    // Conteúdo do app, sem dado pessoal.
    match /achievementsCatalog/{id}               { allow read, write: if false; } // TODO(segurança): leitura autenticada
    match /legalDocuments/{version}               { allow read, write: if false; } // TODO(segurança): leitura pública ou autenticada
  }
}
```

- O curinga recursivo `{document=**}` exige `rules_version = '2'` [C].
- O padrão de dono (`request.auth.uid == userId`) é o exemplo oficial para dados separados por usuário [C].
- **Divergência B6:** as sessões ficam em `users/{uid}/plans/{planId}/sessions`, seguindo a decisão "tudo sob `users/{uid}`" [D].
- **Regras completas:** escritas pela sessão de segurança em `app/firestore.rules`. A doc está em `docs/backend/firestore-rules.md` (v0.5, roteiro completo). **Publicadas em 24/10/2026**, com autorização do usuário: 64/64 testes no emulador antes, e a CLI respondeu "compiled successfully" e "Deploy complete!".
- **Publicar:** pela CLI (`firebase deploy --only firestore:rules --project nexo-app-gestao-f97bb`, a partir de `app/`) [C], só com autorização do usuário.
  - As regras publicadas pela CLI sobrescrevem as do console [C].
  - A propagação leva alguns minutos [C].
- **Emulador só antes de cada deploy** (opção B do usuário, registrada em `firestore-rules.md` §2 e §8): os testes automáticos das regras rodam uma vez e o processo é encerrado no fim. Os testes de uso são no aparelho físico, depois do deploy.
- **Efeito no app:** com as regras publicadas, o app pode ler e gravar seguindo o contrato da `firestore-rules.md`. Como o projeto é único (F2), o teste no aparelho grava no banco real. **Decisão do usuário (24/10/2026): o teste no aparelho só acontece depois da criação da seção Auth no app.**

### 7.3 Backups e retenção (Blaze)

- Backups agendados exigem Blaze [C]. A retenção máxima é de 14 semanas [C], com no máximo um agendamento diário e um semanal por banco [C].
- O PITR exige faturamento e guarda 7 dias [C].
- A retenção dos backups vira o prazo real de eliminação dos dados depois da exclusão da conta (Política 9).
- **Decidido (22/10/2026): até 7 dias.** A Política v0.2 já diz "até 7 dias". Configuração alvo: backup **diário**, retenção **7 dias**, **sem** agendamento semanal e PITR desligado.
- **Corrigido em 24/10/2026, com autorização do usuário:**
  - criado o agendamento **diário** com retenção de 7 dias (`0a34df5a-…`, 604.800 s);
  - apagado o agendamento semanal de 98 dias.
  - Verificado pela CLI: sobra só o diário.
  - O backup de 23/10/2026 (`5f598bc9-…`) foi apagado pelo usuário. Verificado pela CLI: "No backups found".
- Estado encontrado antes da correção (24/10/2026, divergente):
  - Existe um agendamento **semanal (sexta)** com retenção de **8.467.200 s (98 dias, 14 semanas)**, criado junto com o banco em 22/10/2026 às 03:37 UTC.
  - Já existe um backup desse agendamento, de 23/10/2026 22:53 UTC (READY), que fica guardado por 98 dias.
  - O PITR está desligado, como decidido.
  - A proteção contra exclusão do banco foi ligada depois, no item 7.4.
  - Correção: passo 1 do roteiro da seção 12.

### 7.4 Proteção contra exclusão do banco

- **Ligada em 24/10/2026, a pedido do usuário.** Comando: `firebase firestore:databases:update "(default)" --delete-protection ENABLED`. Verificado pela CLI: `DELETE_PROTECTION_ENABLED`.
- Ela impede que o banco `(default)` seja apagado por engano. Para apagar de propósito, é preciso desligar antes (`--delete-protection DISABLED`).
- Não afeta leituras nem gravações [NC].
- **Exclusão de conta:** apagar o documento `users/{uid}` **não** apaga as subcoleções [C].
  - Saídas avaliadas: uma Cloud Function com exclusão recursiva (Admin SDK `recursiveDelete`) [C] ou a extensão "Delete User Data" (exige Blaze [C]; se ela apaga as subcoleções recursivamente: [NC]).
  - **Decidido em 24/10/2026: pelo app, sem Function.** O app marca a conta, apaga as subcoleções e por último o usuário e a conta do Auth. As regras publicadas permitem isso. Detalhes: `firestore-rules.md` §3 e §7.

**Checklist 7**
- [x] Firestore › Data: banco `(default)`, edição Standard, local `southamerica-east1` (verificado pela CLI em 24/10/2026).
- [x] Rules: regras completas (v0.5) publicadas pela CLI em 24/10/2026, no lugar do bloqueio total.
- [x] ~~Rules Playground~~ substituído pelos 64 testes automáticos no emulador, antes do deploy (`firestore-rules.md` §2).
- [x] `legalDocuments/current` criado pelo usuário no console (`terms-2026-11-01` / `privacy-2026-11-01`). Conferido pela leitura pública da API em 24/10/2026.
- [x] Backups: só o agendamento diário, com retenção de 7 dias (`firebase firestore:backups:schedules:list`, 24/10/2026).
- [x] Backup de 23/10/2026 apagado (usuário; "No backups found" na CLI, 24/10/2026).

---

## 8. Crashlytics

**Console (você):** abra o Crashlytics no projeto. Se o assistente pedir o "Nome do pacote do Android", feche sem preencher enquanto F1 estiver aberta. O app é registrado no passo 4. Se é preciso clicar em algo para ativar antes do primeiro relatório: [NC].

**App (nexo-flutter):**
1. `firebase_crashlytics` entra no pubspec **antes** do `flutterfire configure` (passo 3). O configure adiciona o plugin Gradle do Crashlytics [C].
2. Handlers no `main.dart` [C]:
   - `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;`
   - `PlatformDispatcher.instance.onError`, com `recordError(error, stack, fatal: true)`, retornando `true`.
3. Coleta desligada em debug (`setCrashlyticsCollectionEnabled(!kDebugMode)`) [D], para os testes não poluírem os relatórios do projeto único (F2).
4. **Sem Analytics (D2):**
   - O Crashlytics funciona, mas sem breadcrumbs e sem alertas de velocidade [C].
   - A métrica "usuários sem falhas" não depende mais do Analytics no Flutter [C].
5. **Opt-in (decisão jurídica, D6 do advogado):** se a base legal for consentimento em vez de LI:
   - desligue a coleta no nativo com `firebase_crashlytics_collection_enabled=false` no `AndroidManifest.xml`;
   - ligue com `setCrashlyticsCollectionEnabled(true)` quando o usuário aceitar. A escolha persiste entre aberturas do app [C].
6. **Dados pessoais:**
   - Nunca mande e-mail, nome ou texto livre do usuário (nomes de plano, notas, tarefas; risco R8) em `log`, `setCustomKey` ou mensagens de erro [D].
   - Se precisar de identificador, use só o `uid` [D].
7. **Símbolos:** com `--obfuscate --split-debug-info=<pasta>`, rode `firebase crashlytics:symbols:upload --app=<ANDROID_APP_ID> <pasta>`. O `<ANDROID_APP_ID>` é o `mobilesdk_app_id` do `google-services.json` [C].
8. **Retenção:** 90 dias [C]. Preenche parte de B3 (Política 9).

**Checklist 8**
- [ ] Um build de teste com um botão `throw Exception()` gera o crash no console em até 5 minutos [C]. Se não aparecer, ligue o debug logging [C].
  - Como a coleta fica desligada em debug (item 3), o teste precisa de um build **release ou profile** no aparelho físico. Exemplo: `flutter run --release`, que no template padrão assina com a chave de debug [NC neste projeto].
- [ ] O relatório não contém e-mail, nome nem texto livre.
- [ ] O `pubspec.lock` não contém `firebase_analytics`.

---

## 9. Cloud Messaging e Cloud Functions (fora deste guia)

- O FCM é gratuito [C]. A configuração do push (permissão e tokens em `users/{uid}/devices`) fica para a sessão de notificações.
- O deploy de Cloud Functions exige Blaze [C], já contratado (F4). A configuração fica para a sessão de backend.
  - O Node.js das Functions é 20 ou 22 [C].
  - As funções agendadas usam o Cloud Scheduler: US$ 0,10 por job por mês, com 3 jobs grátis por conta [C].
  - Nas agendadas, use o fuso `America/Sao_Paulo` [C para a opção `timeZone`].

---

## 10. App Check (depois do MVP, F5)

O que precisa estar pronto **antes do lançamento público**:
- **Play Integrity:**
  - SHA-256 do certificado de assinatura e o projeto vinculado no Play Console ("Link Cloud project", papel Owner) [C].
  - A cota padrão é de 10.000 chamadas por dia. Para aumentar, o app precisa estar no Google Play [C].
  - Builds fora do Play não recebem `PLAY_RECOGNIZED` [C].
- **Desenvolvimento:** debug provider, com o token registrado em "Manage debug tokens". O token nunca vai para o repositório [C].
- **Ordem:**
  1. Ativar no app.
  2. Monitorar as métricas (Verified, Outdated, Unknown, Invalid).
  3. Impor por produto: primeiro o Firestore, depois o Auth. O Auth aparece como Preview numa das páginas [C, divergência].
  4. A imposição leva até 15 minutos para valer [C].
- **Atenção:** impor num app já lançado quebra as versões anteriores, que não têm App Check [C]. Por isso, o ideal é **ativar o SDK no app antes da primeira versão pública**, mesmo que a imposição venha depois [D].
- **Custo:** o App Check é gratuito, sujeito às cotas dos provedores [C].

---

## 11. Pendências para o app

Modo de trabalho decidido pelo usuário em 24/10/2026: primeiro termina **toda** a configuração do Firebase. Flutter e design estão pausados. Tudo o que exigir código em `app/` ou mudança nos `.pen` fica registrado aqui e só é pedido às sessões depois.

### 11.1 Já feito no app (verificado em 22/10/2026)

- Pacote `dev.emanoelbarbosa.nexo` no Android (`namespace`, `applicationId` e `MainActivity`).
- `minSdk = maxOf(flutter.minSdkVersion, 24)`.
- Pacotes `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_crashlytics` e `google_sign_in`, sem `firebase_analytics`.
- `flutterfire configure` só Android: `firebase_options.dart` e `firebase.json` sem `ios`.
- `main.dart` com `Firebase.initializeApp` e handlers do Crashlytics, com a coleta desligada em debug.
- `flutter analyze` sem problemas e `flutter build apk --debug` concluído.

### 11.2 Pendente

| # | Pendência | Onde | Origem | Motivo |
|---|---|---|---|---|
| A1 | `FirebaseAuthRepository` atrás de `AuthRepository`. Detalhes nos itens abaixo | `app/lib` | §6.0, §6.1; spec `auth-redefinicao-senha.md` §7 | Hoje o auth é fake. O app ainda não tem pasta de auth (verificado em 24/10/2026) |
| A1.1 | Tratar `invalid-credential` | `app/lib` | §6.0 | `user-not-found` e `wrong-password` estão deprecated com a enumeration protection [C] |
| A1.2 | Normalizar o prefixo `auth/` dos códigos de erro | `app/lib` | spec §7 | O código pode vir com ou sem o prefixo [NC] |
| A1.3 | `setLanguageCode('pt-BR')` antes dos e-mails | `app/lib` | §6.3 | Para os e-mails saírem em pt-BR |
| A1.4 | `sendPasswordResetEmail` sem `ActionCodeSettings` | `app/lib` | R1 | O reset usa a página padrão do Firebase |
| A1.5 | `validatePassword` com a regra R5 (8+, maiúscula, minúscula, número, especial) | `app/lib` | §6.1 | Política de senha do projeto |
| A2 | Login Google com `GoogleSignIn.instance.initialize(...)` + `authenticate()`, depois a credencial do Firebase | `app/lib` | §6.2 | O provedor Google está ativo no console e os SHA de debug estão cadastrados |
| A3 | Gravações no Firestore conforme `docs/backend/firestore-rules.md` (nomes de campos, `serverTimestamp`, inteiros). Lista completa do que o app implementa: seção 7 daquela doc | `app/lib` | regras v0.5, publicadas em 24/10/2026 | As regras validam campo a campo |
| ~~A4~~ | ~~`firebase-debug.log` no `.gitignore`~~ **Feito em 24/10/2026, a pedido do usuário** | `app/.gitignore` | §5.1 | — |
| A5 | Keystore de upload + `key.properties` (fora do git) e `signingConfig` de release; passar os SHA-1/SHA-256 ao usuário | `app/android` | §6.2 | Login Google e restrição de API key no build de release. O usuário guarda as senhas |
| A6 | Opção de crash de teste num build release ou profile | `app/lib` | §8, checklist 8 | A coleta está desligada em debug |
| A7 | Nenhum botão ou fluxo de login Apple no app | `app/lib` | F7 | Nada da Apple no MVP. Hoje só há um comentário de tema (`nexo_theme.dart`, "botão Apple") |
| A8 | `PRODUCT_BUNDLE_IDENTIFIER` do iOS ainda `com.example.nexo` | `app/ios` | F6 | Baixa prioridade: o iOS está fora do MVP. Não bloqueia nada |
| A9 | Flavors `dev` (`applicationIdSuffix = ".dev"`, nome visível próprio) e `prod` | `app/android/app/build.gradle.kts` | F2 (26/10/2026), §14.4 | Dois projetos Firebase; o par pacote + SHA-1 é único entre projetos [C] |
| A10 | `flutterfire configure` por ambiente: `firebase_options_dev.dart`/`_prod.dart` e `src/dev`/`src/prod/google-services.json`. Removem-se o arquivo único e o `firebase_options.dart` | `app/lib`, `app/android` | §14.4 | Cada build aponta para o seu projeto |
| A11 | Ponto de entrada por ambiente (`main_dev.dart`/`main_prod.dart` ou `--dart-define`) e comandos de run/build com `--flavor` | `app/lib` | §14.4 | Escolher o projeto em tempo de build |
| A12 | `.firebaserc` com os aliases `dev`/`prod`. Comandos do AGENTS.md §8 com `--project` explícito (proposta de diff ao usuário) | `app/`, `AGENTS.md` | §14.5 | Deploy das regras sem risco de cair no projeto errado |
| A13 | Política de TTL de 30 dias na coleção `users/{uid}/notifications` (campo de expiração definido no contrato), configurada no console em cada projeto | console (você) | `firestore-rules.md` §7, histórico de notificações (04/11/2026) | Guarda de 30 dias decidida pelo usuário. O TTL apaga com atraso e cada exclusão conta como uma operação de exclusão [NC] |
| D1 | Tela 03 Cadastro mostra a regra de senha R5 exatamente | `.pen` | §6.1 | O design precisa bater com a política do Firebase |
| D2 | Remover do design os botões e fluxos de login Apple | `.pen` | F7 | Conferir se ainda existem: a confirmar com a prototipação |

## 12. Roteiro de console restante (proposto em 24/10/2026)

Um passo por vez, sempre com explicação antes e autorização do usuário.

| Ordem | Passo | Seção | Quem |
|---|---|---|---|
| 1 | ~~Backups~~ **Feito em 24/10/2026.** Só o agendamento diário de 7 dias; o backup de 23/10 foi apagado pelo usuário (CLI: "No backups found") | §7.3 | — |
| 2 | Conferências: ~~Require~~ e ~~Owner~~ confirmados pelo usuário em 24/10/2026. **Template Password reset (bloqueado pelo console): decidido em 25/10/2026, plano B:** o MVP usa o texto padrão do Firebase em pt-BR. O chamado ao suporte fica para depois. Conferir o texto no primeiro teste no aparelho | §6.3 | — |
| 3 | ~~Proteção contra exclusão do banco~~ **Feito em 24/10/2026** | §7.4 | — |
| 4 | ~~Cota de `identitytoolkit.googleapis.com`~~ **Decidido em 24/10/2026: não mexer no MVP.** Fica só a proteção automática de 100 contas novas por hora por IP | §5.2 item 4 | — |
| 5 | ~~Deploy das regras completas do Firestore~~ **Feito em 24/10/2026** (v0.5). `legalDocuments/current` e `achievementsCatalog` (9 medalhas) criados pelo usuário e conferidos em 24/10/2026 (`firestore-rules.md` §4 e §8) | §7.2 | — |
| 6 | Restrição das API keys (Android: pacote + SHA-1) e conferir se sobrou uma chave iOS | §5.2 | Depois do primeiro teste no aparelho |
| 7 | SHA de release (upload e Play App Signing) | §6.2 | Depende de A5 e do Play Console |

---

## 13. Referências oficiais (consultadas em 21/10/2026)

- Firebase CLI: https://firebase.google.com/docs/cli · requisito de Node no `package.json`: https://github.com/firebase/firebase-tools · notas: https://firebase.google.com/support/release-notes/cli
- FlutterFire setup: https://firebase.google.com/docs/flutter/setup · CLI e README (Windows/npm, flags): https://github.com/invertase/flutterfire_cli · pacote: https://pub.dev/packages/flutterfire_cli
- PATH do pub cache: https://dart.dev/tools/pub/cmd/pub-global
- Versões: https://pub.dev/packages/firebase_core/changelog · https://pub.dev/packages/firebase_auth/changelog · https://firebase.google.com/support/release-notes/flutter
- Projetos e ambientes: https://firebase.google.com/docs/projects/dev-workflows/general-best-practices · https://firebase.google.com/docs/projects/multiprojects · locais: https://firebase.google.com/docs/projects/locations
- API keys: https://firebase.google.com/docs/projects/api-keys · security checklist: https://firebase.google.com/support/guides/security-checklist
- Preços e faturamento: https://firebase.google.com/pricing · https://firebase.google.com/docs/projects/billing/avoid-surprise-bills · https://docs.cloud.google.com/billing/docs/how-to/budgets · https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps
- Auth: https://firebase.google.com/docs/auth/flutter/password-auth · https://firebase.google.com/docs/auth/flutter/federated-auth · https://firebase.google.com/docs/auth/flutter/manage-users · https://firebase.google.com/docs/auth/limits · https://firebase.google.com/docs/auth/faq-and-troubleshooting · https://firebase.google.com/docs/auth/email-custom-domain · https://docs.cloud.google.com/identity-platform/docs/admin/email-enumeration-protection · https://docs.cloud.google.com/identity-platform/docs/password-policy
- Google Sign-In: https://pub.dev/packages/google_sign_in · https://pub.dev/packages/google_sign_in_android · https://firebase.google.com/docs/auth/android/google-signin · SHA: https://developers.google.com/android/guides/client-auth · https://support.google.com/firebase/answer/9137403
- Firestore: https://firebase.google.com/docs/firestore/editions · https://firebase.google.com/docs/firestore/quickstart · https://firebase.google.com/docs/firestore/locations · https://firebase.google.com/docs/firestore/manage-databases · https://firebase.google.com/docs/firestore/quotas · https://firebase.google.com/docs/firestore/backups · https://firebase.google.com/docs/firestore/pitr · https://firebase.google.com/docs/firestore/manage-data/delete-data · https://firebase.google.com/docs/firestore/solutions/delete-collections
- Regras: https://firebase.google.com/docs/rules/basics · https://firebase.google.com/docs/firestore/security/rules-structure · https://firebase.google.com/docs/rules/manage-deploy · emulador: https://firebase.google.com/docs/emulator-suite/install_and_configure
- Crashlytics: https://firebase.google.com/docs/crashlytics/flutter/get-started · https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports · https://firebase.google.com/docs/crashlytics/crash-free-metrics · https://firebase.google.com/docs/crashlytics/troubleshooting · retenção: https://firebase.google.com/support/privacy
- Functions: https://firebase.google.com/docs/functions/get-started · https://firebase.google.com/docs/functions/schedule-functions · extensão Delete User Data: https://extensions.dev/extensions/firebase/delete-user-data
- App Check: https://firebase.google.com/docs/app-check · https://firebase.google.com/docs/app-check/flutter/default-providers · https://firebase.google.com/docs/app-check/flutter/debug-provider · https://firebase.google.com/docs/app-check/android/play-integrity-provider · https://firebase.google.com/docs/app-check/monitor-metrics · https://firebase.google.com/docs/app-check/enable-enforcement · https://developer.android.com/google/play/integrity/setup

### Itens verificados à parte (P1–P4)

- **P1. Project ID permanente:**
  - "After project creation, the project ID is permanent". https://docs.cloud.google.com/resource-manager/docs/creating-managing-projects
  - Veja também https://firebase.google.com/docs/projects/learn-more#project-id
- **P2. Application ID:**
  - "Once you publish your app, you should never change the application ID". https://developer.android.com/build/configure-app-module
  - O Play não aceita dois apps com o mesmo package name. https://support.google.com/googleplay/android-developer/answer/9061737
  - Se o Play rejeita `com.example`: [NC], sem fonte oficial.
- **P3. Public-facing name:** fica na página Settings e aparece nos e-mails. O caminho exato do menu é [NC]. https://support.google.com/firebase/answer/7000714 · https://support.google.com/firebase/answer/9137752
- **P4. Upgrade para Blaze:** é feito no console, vinculando uma conta do Cloud Billing. https://firebase.google.com/docs/projects/billing/firebase-pricing-plans
- **P5. Par pacote + SHA-1 único entre projetos:** "This error occurs if we detect that another Firebase or Google Cloud project contains an OAuth 2.0 client ID" com o mesmo pacote e SHA-1. Saídas oficiais: usar outro pacote ou outra chave, ou apagar o SHA-1 no outro projeto, o que também remove o client OAuth. https://support.google.com/firebase/answer/6401008
- **P6. Aliases da CLI:** `firebase use --add` grava os aliases no `.firebaserc`, e `--project` vale em qualquer comando (ex.: `firebase deploy --project=prod`). https://firebase.google.com/docs/cli
- **P7. `google-services.json` por variante:** um arquivo por pasta de variante (ex.: `src/development/google-services.json`, `src/release/google-services.json`). https://firebase.google.com/docs/projects/multiprojects

---

## 14. Separação dev × prod (cancelada em 04/11/2026)

- Em 26/10/2026 o usuário decidiu separar desenvolvimento e produção em dois projetos Firebase. A proposta (papel de cada projeto, IDs, pacote `.dev`, flavors, `.firebaserc`) ficou aguardando as escolhas E1, E2 e E4.
- **Em 04/11/2026 o usuário decidiu manter um projeto só** (F2): `nexo-app-gestao-f97bb`. Nada tinha sido feito no console. As pendências A9–A12 foram retiradas.
- Se a separação voltar, as restrições confirmadas continuam valendo: o par pacote + SHA-1 é único entre projetos (P5), os aliases da CLI ficam no `.firebaserc` (P6) e o `google-services.json` vai por pasta de variante (P7).
