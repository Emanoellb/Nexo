# Nexo · Security Rules do Cloud Firestore (MVP)

Status: **v0.7 publicada em 04/11/2026**, com autorização do usuário ("pode publicar"): `deleting` passa a ser terminal e o plano em exclusão não recebe filhos novos (achado [4] da revisão de código de 04/11/2026). Antes: **v0.6 em 25/10/2026** (tópicos do plano, cor da disciplina, situação da entrega), com os **3 índices compostos** (seção 4.1), com autorização do usuário ("pode criar e publicar"). Antes: v0.5, publicada em 24/10/2026. Roteiro completo (etapas 1 a 11) decidido pelo usuário em 22 e 24/10/2026. **Deploy em 24/10/2026** no projeto `nexo-app-gestao-f97bb`, com autorização do usuário ("pode publicar"): regras compiladas e liberadas sem erro. · Sessão: segurança do Firestore · 24/10/2026
Base: `docs/backend/firebase-setup.md` §7.2 (esqueleto e mapa), `docs/legal/inventario-dados-mvp.md` e as telas do `nexo.lib.pen` (`ca7IW` Regras e requisitos, `oXRSc` Fluxo do Plano de ação) e do `nexo.app.pen` (fluxo de entrada).

Legenda: **[C]** confirmado na documentação oficial · **[NC]** não confirmado · **[D]** decisão do usuário.

## 1. Arquivos

| Arquivo | O que é |
|---|---|
| `app/firestore.rules` | Regras versionadas. Fonte da verdade depois do deploy pela CLI |
| `app/firebase.json` | Chave `"firestore": {"rules": "firestore.rules", "indexes": "firestore.indexes.json"}` ao lado do bloco `flutter` do FlutterFire (combinado com a nexo-flutter). O `firebase deploy` lê os caminhos dali. Sem bloco `emulators` |
| `app/firestore.indexes.json` | Índices compostos versionados (seção 4.1) |
| `app/firestore_tests/` | Testes das regras (Node, `node:test` + `@firebase/rules-unit-testing` 6.0.0 + `firebase` 13.0.0, versões fixadas). Exceção aceita pelo usuário (22/10/2026) à regra "em `app/` só o que o Flutter cria". Não tem `.dart` e não entra no build |
| `app/.gitignore` | `node_modules/`, logs do emulador e `firebase-debug.log` |

## 2. Testes

- **Sem emulador no dia a dia** (decisão de 22/10/2026). Os testes de uso ficam no aparelho físico.
- **Exceção (24/10/2026): o emulador roda uma vez antes de cada deploy das regras**, com os testes automáticos de `firestore_tests/`. Quem roda explica antes e, ao terminar, confere a porta 8080 e encerra o processo Java do emulador. No Windows, o `emulators:exec` costuma deixar esse processo aberto.
- **Limite:** os testes só rodam no emulador. O aparelho físico testa as regras **publicadas** no projeto real, que é único (F2): os testes no aparelho gravam no mesmo banco dos usuários reais.

Histórico de execuções:

| Data | Versão | Resultado |
|---|---|---|
| 22/10/2026 | v0.2 | 54/54. Teste de mutação: 5 verificações enfraquecidas → os 6 testes correspondentes falharam (48/54), mostrando que os testes negam pelo motivo certo |
| 24/10/2026 | v0.5 | **64/64** (execução única antes do deploy). O processo Java do emulador ficou aberto de novo e foi encerrado ao final |
| 25/10/2026 | v0.6 | **71/71** (execução única antes do deploy). Processo do emulador encerrado ao final |
| 04/11/2026 | v0.7 | **75/75** (execução única antes do deploy; 4 testes novos em "plano em exclusão"). O processo Java soltou a porta 8080, mas ficou vivo; foi encerrado ao final |

Instalação global (uma vez por máquina, não muda o repositório): Node 20+, Firebase CLI e JDK 11+. Esta máquina tem Node 22.17, CLI 15.28.2 e JDK 23. O emulador do Firestore já está em `~/.cache/firebase/emulators`.

No projeto, a partir de `app/`:

```bash
npm --prefix firestore_tests ci
```

Instala as dependências fixadas no `package-lock.json` (só para os testes; o `node_modules/` fica fora do git).

```bash
firebase emulators:exec --only firestore --project demo-nexo "npm --prefix firestore_tests test"
```

Sobe o emulador, roda os testes e derruba o emulador. O projeto `demo-nexo` é fictício: com o prefixo `demo-`, a CLI não acessa nenhum projeto real [C].

**`npm audit`:** acusa 5 alertas "high" vindos do `@grpc/grpc-js` que o SDK `firebase` puxa. São falhas do lado servidor do gRPC; aqui o pacote só roda na máquina, contra o emulador local. Nada disso vai para o app Flutter.

## 3. Princípios

1. **Dono com e-mail verificado:** tudo sob `users/{uid}` exige `request.auth.uid == uid` [C, padrão oficial] **e** `request.auth.token.email_verified == true`. Única exceção: criar o próprio `users/{uid}` no Cadastro, antes da verificação, para gravar o aceite e a data de nascimento no momento do clique. Não há leitura entre usuários.
   - O Google já entrega o e-mail verificado.
   - Na conta de e-mail e senha, depois do "Já confirmei" (tela 05), o app chama `reload()` e **`getIdToken(true)`**. Sem renovar o token, as regras ainda veem `email_verified == false` e negam.
2. **Sem Cloud Function no MVP** [D]: o app grava e calcula dias, pontos e conquistas, para não gastar créditos. As regras validam formato e limites, mas não conseguem garantir que os pontos estão certos. Um usuário técnico poderia alterar os próprios pontos; como não há ranking, isso só afeta ele mesmo.
3. **Lista branca de campos:** cada coleção tem a lista do que o app pode gravar. No create, `keys().hasOnly(...)` + `hasAll(obrigatórios)`. No update, `diff().affectedKeys().hasOnly(...)`. Campo fora do contrato é negado.
4. **Carimbos do servidor:** `createdAt`, `updatedAt`, `consents.acceptedAt`, `tasks.completedAt`, `days.finalizedAt`, `achievements.earnedAt` e `users.deletionRequestedAt` precisam ser `FieldValue.serverTimestamp()` (`== request.time`). `createdAt` não muda depois. Funciona offline: o servidor resolve o carimbo na hora de gravar.
5. **Janela de 7 dias:** sessões e dias só são criados, editados ou finalizados até 7 dias para trás (RF11, RF14). As regras só conhecem o UTC e aceitam até 9 dias, como folga para qualquer fuso.
6. **Excluir pelo app:** plano com `status: "deleting"` e usuário com `deletionRequestedAt` liberam apagar o que normalmente é imutável (versões, dias, conquistas, sessões antigas). Se o app fechar no meio, retoma depois.
   - **As duas marcações são terminais.** `deletionRequestedAt` não pode ser desfeito; o plano em `deleting` fica **congelado** (nenhum update) e só sai apagando (v0.7, 04/11/2026). Sem isso, um cliente modificado marcaria `deleting`, apagaria o histórico antigo e voltaria o plano para `active`.
   - Plano em `deleting` não recebe sessão, dia, tópico nem versão nova.
7. **Notificações locais** [D]: agendadas no aparelho. Nada de token FCM, `devices` ou `notificationLog` no Firestore.
8. **Conteúdo do app:** `achievementsCatalog` (leitura com login) e `legalDocuments` (leitura pública) são somente leitura; carregados pelo console.
9. **Negação por padrão:** coleção fora do mapa é negada.

## 4. Contrato de campos

Nenhum campo é gravado por Cloud Function no MVP: **quem grava é sempre o app**, e as regras validam.

### `users/{uid}` (etapas 1, 3, 9 e 11)

Telas: 03 Cadastro, 03b Primeiro acesso com Google, 05 Verifique seu e-mail, 06 Tutorial, Perfil. Splash, Login e Esqueci a senha não gravam no Firestore (só o Firebase Auth).

| Campo | Tela / origem | Tipo e validação | Obrig. |
|---|---|---|---|
| `displayName` | "Nome" no Cadastro; no 03b vem do Google, editável; Editar perfil | string 1–80 | sim |
| `birthDate` | "Data de nascimento" no Cadastro e no 03b | `AAAA-MM-DD`, ano ≥ 1900, **16 anos ou mais** na data UTC do servidor. Só na criação: o app não altera (correção pelo canal de contato) | sim |
| `consents` | caixas de aceite do Cadastro e do 03b | `{termsVersion, privacyVersion, acceptedAt}`. Versões **iguais às de `legalDocuments/current`**; `acceptedAt` = serverTimestamp | sim |
| `timeZone` | aparelho, sem tela | string IANA (`America/Sao_Paulo`), até 64. Usado na divisão à meia-noite e nos avisos | sim |
| `tutorialSeen` | qualquer uma das 3 saídas do passo 5 do tutorial | bool | não |
| `primaryPlanId` | marcar plano principal (RF07) | id de um plano do próprio usuário (conferido com `existsAfter`) ou null | não |
| `overloadThreshold` | Perfil: limite de "sobrecarregado" | int 1–20, em **tarefas por dia**. Vazio = padrão 5 no app | não |
| `points` | progresso (etapa 9) | int 0–10.000.000. Começa em 0; o app soma e subtrai | não |
| `deletionRequestedAt` | Excluir conta | serverTimestamp, gravado uma vez; não pode ser desfeito | não |
| `createdAt`, `updatedAt` | servidor | serverTimestamp | sim |

- **Sem aceite e sem data de nascimento não existe documento do usuário.**
- Idioma não é guardado (MVP só em pt-BR). Foto de perfil não entra.
- Novo aceite (nova versão vigente) substitui o mapa inteiro. Regravar uma versão antiga é negado. O aceite não pode ser removido.
- A idade é conferida pela data **UTC** do servidor: no horário de Brasília (UTC−3), os 16 anos passam a valer às 21h da véspera do aniversário. Diferença aceita.
- Nível, sequência atual e maior sequência são calculados pelo app (nível a partir de `points`; sequências a partir dos dias). Não são guardados.

### `users/{uid}/plans/{planId}` (etapa 3)

Telas: 02 Planos, 03 Novo plano, 07 Visão geral. MVP: RF01, RF02, RF04–RF07. **RF03 (categoria e tópicos) fica fora do MVP** (`ca7IW`, item 12).

| Campo | Tela / RF | Tipo e validação | Obrig. |
|---|---|---|---|
| `name` | Nome do plano (RF01) | string 1–80. Edição vale na hora | sim |
| `startDate` | Início (RF01) | `AAAA-MM-DD`, **até 7 dias para trás** | sim |
| `endDate` | Fim (RF01) | `AAAA-MM-DD`, ≥ início, **período de até 2 anos** | sim |
| `frequency` | Todos os dias · Dias da semana · × por semana (RF02) | `{type: "daily"}` · `{type: "weekdays", weekdays: [1..7]}` · `{type: "timesPerWeek", timesPerWeek: 1..7}`. Números como no Dart: 1 = segunda … 7 = domingo | sim |
| `dailyGoalMinutes` | Meta diária "5h" (RF01) | int 1–1440, em minutos. A tela usa passos de 15 min | sim |
| `status` | Planos; pausar, encerrar, arquivar, excluir (RF05, RF06) | `active`, `paused`, `completed`, `endedEarly`, `archived`, `deleting` (este só em update, e sem volta) | sim |
| `pauses` | Pausar/retomar (RF05) | lista de `{start, end}` (datas; `end` null enquanto pausado), até 100 itens | não |
| `endedOn` | Encerrar antes (RF06) | `AAAA-MM-DD` dentro do período; **obrigatório** com `endedEarly`; continua se o plano for arquivado | não |
| `goalId` | objetivo (etapa 8) | string 1–128 ou null | não |
| `reminder` | Lembrete diário · 19:00 | `{enabled, time: "HH:mm"}`. Notificação local | não |
| `createdAt`, `updatedAt` | servidor | serverTimestamp | sim |

- **Plano principal: `users.primaryPlanId`**, não `isPrimary` no plano. Para apagar o plano principal, o app limpa o `primaryPlanId` na mesma operação (lote).
- **Pausa:** vale **a partir de hoje**, se o dia ainda não foi finalizado. Retomar também. Dias pausados viram "Folga/Pausado" e saem da conta (lógica do app).
- **Semana: domingo a sábado.** Vale para o "× por semana" e para o calendário (como no design: D S T Q Q S S).
- `frequency` e `dailyGoalMinutes` no plano são a cópia da configuração mais recente, usada na lista. O histórico fica em `scheduleVersions`.
- Totais da Visão geral e do Relatório (horas, saldo, sequência, pontos, dias por status) são **calculados pelo app** a partir dos dias e das versões.
- **Excluir plano:** o app marca `status: "deleting"`, apaga sessões, dias e versões em lotes e, por último, o plano. A marcação **não tem volta**: depois dela, as regras negam qualquer update do plano (inclusive voltar para outro status ou mudar o nome) e qualquer criação de sessão, dia, tópico ou versão nele. Por isso, o app só marca depois de o usuário confirmar a exclusão.

### `…/plans/{planId}/scheduleVersions/{versionId}` (etapa 3)

Histórico das configurações com vigência (RF04: "mudanças valem a partir do dia seguinte").

- Campos: `effectiveFrom` (`AAAA-MM-DD`, dentro do período), `frequency`, `dailyGoalMinutes`, `createdAt` (serverTimestamp).
- **A configuração inicial também é uma versão** (`effectiveFrom` = início), criada no mesmo lote que o plano. Por isso as regras usam `existsAfter`/`getAfter`.
- Cada edição de meta ou frequência cria uma versão com `effectiveFrom` = amanhã no fuso do usuário (ou o início, se o plano não começou).
- Meta de um dia: a versão mais recente com `effectiveFrom` ≤ dia. Dia pausado ou fora da frequência = folga.
- O app só **cria**. Update negado; delete só ao excluir o plano ou a conta.

### `…/plans/{planId}/topics/{topicId}` (decidido em 25/10/2026)

Cada plano tem os **seus tópicos**. Dentro de uma matéria pode haver vários tópicos (ex.: Matemática → "Porcentagem", "Juros simples"). Um tópico pode **reaproveitar uma matéria** que o usuário já usa nas tarefas ou ser **novo, só do plano**: concurso ou qualquer outro assunto.

| Campo | Tipo e validação | Obrig. |
|---|---|---|
| `name` | string 1–80 | sim |
| `subjectId` | matéria (disciplina) a que o tópico pertence, ou null | não |
| `createdAt`, `updatedAt` | serverTimestamp | sim |

- Pode ser criado junto com o plano (mesmo lote) ou depois; por isso as regras usam `existsAfter`.
- O app renomeia e apaga quando quiser. Sessão que apontava para um tópico apagado mostra "sem tópico".
- Na interface do plano, a palavra é sempre "tópico".

### `…/plans/{planId}/sessions/{sessionId}` (etapa 4)

Telas: 04 Sessão de foco, 09 Sessões, 10 Registrar horas. RF08–RF13.

| Campo | Tipo e validação | Obrig. |
|---|---|---|
| `startAt`, `endAt` | timestamps; fim > início; até 24 h; no máximo 5 min no futuro | sim |
| `durationSeconds` | int > 0 e ≤ fim − início (**duração líquida**, já sem as pausas) | sim |
| `source` | `focus` ou `manual` | sim |
| `day` | `AAAA-MM-DD`, o dia a que a sessão pertence; **dentro da janela de 7 dias** | sim |
| `topicId` | "Tópico" = um **tópico do próprio plano** (`topics`), ou null | não |
| `note` | string 1–500 ou null | não |
| `createdAt`, `updatedAt` | serverTimestamp | sim |

- **O cronômetro em andamento fica no aparelho**: o horário de início é guardado localmente e a sessão só vai ao Firestore ao "Encerrar sessão". Não há sessão "aberta" no banco.
- As pausas da sessão não são guardadas, só a duração líquida.
- **Divisão à meia-noite (RF13):** cada dia tem meta, status e pontos próprios e fecha à meia-noite no fuso do usuário. Uma sessão das 23h30 à 0h45 vira duas: 30 min no primeiro dia e 45 min no seguinte. Quem divide é o app, ao salvar.
- Criar, editar e excluir só dentro da janela de 7 dias (RF11, RF12). Fora dela, só ao excluir o plano ou a conta.
- Create só se o plano existir (1 leitura extra).

### `…/plans/{planId}/days/{AAAA-MM-DD}` (etapa 5)

Telas: 05 Finalizar o dia, 06 Dia cumprido, 08 Calendário do plano. RF14–RF17.

| Campo | Tipo e validação | Obrig. |
|---|---|---|
| `doneMinutes` | int 0–1440: soma das sessões do dia, atualizada no **mesmo lote** que a sessão | sim |
| `finalizedAt` | serverTimestamp ao finalizar; **null no Desfazer** (RF17) | sim (pode ser null) |
| `createdAt`, `updatedAt` | serverTimestamp | sim |

- O id do documento é a data local do dia.
- **Meta, status e pontos do dia não são guardados**: o app calcula pela regra do `ca7IW` (item 05) a partir da meta da versão vigente, de `doneMinutes`, de `finalizedAt` e da data.
- O documento só existe para dias com sessão ou finalização. Dia sem documento = 0 min, não finalizado.
- Criar, atualizar e finalizar só dentro da janela de 7 dias (RF14 retroativo). Estudar depois de finalizar soma horas ao mesmo dia (RF16).
- Delete só ao excluir o plano ou a conta.

### `users/{uid}/tasks/{taskId}` (etapa 6)

| Campo | Tipo e validação | Obrig. |
|---|---|---|
| `title` | string 1–200 | sim |
| `priority` | `high`, `medium`, `low`, `none` | sim |
| `completed` | bool | sim |
| `completedAt` | null se não concluída; serverTimestamp quando muda para concluída | sim (pode ser null) |
| `subjectId` | disciplina, ou null | não |
| `dueAt` | timestamp ou null ("Sem prazo") | não |
| `reminderMinutesBefore` | **aviso de entrega próxima** (notificação local): int 1–43.200 (até 30 dias). Opções da tela: 1 hora (60), 1 dia (1.440), 1 semana (10.080) ou personalizado. Só com prazo. Um aviso por tarefa | não |
| `deliveryStatus` | **situação da entrega**: `notStarted` (Não iniciada), `inProgress` (Em andamento), `delivered` (Entregue), `awaitingGrade` (Aguardando correção), ou null. **Coerente com a conclusão:** pendente só `notStarted`/`inProgress`; concluída só `delivered`/`awaitingGrade` | não |
| `createdAt`, `updatedAt` | serverTimestamp | sim |

- **Situação da entrega entra no MVP** (decisão de 25/10/2026). Ao concluir uma tarefa com situação, o app troca para "Entregue" no mesmo gravar; ao reabrir, volta para "Em andamento".
- "Notas" **ficam fora do MVP** (sem tela).
- "Atrasada" é calculada pelo prazo.
- Ponto da tarefa: +1 ao concluir, −1 ao reabrir (Desfazer), em `users.points`.

### `users/{uid}/subjects/{subjectId}` (etapa 7)

`name` (1–80), `icon` (1–64, nome do ícone Lucide), **`color`** (1–32, nome de uma cor da **paleta fixa** do design, não código de cor livre), `createdAt`, `updatedAt`. Todos obrigatórios.

- O usuário escolhe ícone e cor (decisão de 25/10/2026). **Isso muda o que o inventário e o design diziam ("cor por disciplina = Future").** A paleta ainda precisa ser definida pelo design; quando estiver, as regras podem passar a aceitar só os nomes dela.
- "8 de 12 entregas" e a próxima entrega são **calculados pelo app** a partir das tarefas da disciplina.

### `users/{uid}/goals/{goalId}` (etapa 8)

`name` (1–80, obrig.), `description` (0–500 ou null), `deadline` (`AAAA-MM-DD` ou null), `createdAt`, `updatedAt`. O app cria, altera e apaga.

### `users/{uid}/achievements/{achievementId}` (etapa 9)

- `earnedAt` (serverTimestamp), único campo.
- O id precisa existir em `achievementsCatalog` (1 leitura).
- O app grava quando o critério é atingido. Não muda depois; delete só ao excluir a conta.

### Conteúdo do app (carregado pelo console)

- `achievementsCatalog/{id}`: medalhas. Leitura com login; sem escrita pelo app. **Catálogo do MVP (decidido pelo usuário em 24/10/2026, 9 medalhas):**

  | `order` | ID do documento | `title` | `criterion` | `icon` (Lucide) |
  |---|---|---|---|---|
  | 1 | `primeiro-plano` | Primeiro plano | Crie seu primeiro plano de ação. | `flag` |
  | 2 | `primeiro-foco` | Primeiro foco | Encerre sua primeira sessão de foco. | `timer` |
  | 3 | `primeiro-dia` | Primeiro dia cumprido | Cumpra um dia de plano. | `calendar-check` |
  | 4 | `sete-dias` | 7 dias seguidos | Chegue a uma sequência de 7 dias cumpridos. | `flame` |
  | 5 | `catorze-dias` | 14 dias seguidos | Chegue a uma sequência de 14 dias cumpridos. | `flame` |
  | 6 | `vinte-um-dias` | 21 dias seguidos | Chegue a uma sequência de 21 dias cumpridos. | `flame` |
  | 7 | `trinta-dias` | 30 dias seguidos | Chegue a uma sequência de 30 dias cumpridos. | `zap` |
  | 8 | `dez-tarefas` | 10 tarefas concluídas | Conclua 10 tarefas. | `list-checks` |
  | 9 | `plano-concluido` | Plano concluído | Chegue ao fim do período de um plano. | `trophy` |

  - Campos de cada documento: `title`, `criterion` e `icon` (string) e `order` (number).
  - A medalha não soma pontos. Uma vez ganha, não se perde, mesmo que o usuário desfaça o dia.
  - "Primeira prova organizada", exemplo do design, ficou fora: o MVP não tem o conceito de prova.
  - **"Semana em dia" foi removida (24/10/2026):** num plano diário ela repetia a "7 dias seguidos". O usuário renumerou o `order` de 1 a 9.
  - **Conferido em 24/10/2026** pela consulta `order >= 1` (number) no console, print do usuário: "1 - 9 de 9", todos os campos iguais a esta tabela.
- `legalDocuments/{id}`: leitura pública; sem escrita pelo app.
  - **`legalDocuments/current`** = `{termsVersion, privacyVersion}`, as versões vigentes. Formato sugerido: `terms-AAAA-MM-DD` e `privacy-AAAA-MM-DD`.
  - **Precisa existir antes de o app criar a primeira conta.** Sem ele, as regras negam todo cadastro.
  - Nova versão: atualizar o `current`. O app compara com o `consents` do usuário e pede novo aceite.

### 4.1 Índices compostos (`app/firestore.indexes.json`)

Publicados em 25/10/2026 junto com as regras v0.6. Filtros simples são indexados sozinhos pelo Firestore; estes três cobrem as listas que filtram e ordenam ao mesmo tempo.

| Coleção | Campos | Lista do app |
|---|---|---|
| `tasks` | `completed` + `dueAt` | Tarefas pendentes por prazo (Home "Hoje", aba Tarefas) |
| `tasks` | `subjectId` + `completed` + `dueAt` | Próxima entrega de cada disciplina |
| `sessions` | `day` + `startAt` | Sessões de um dia, em ordem (Calendário do plano, aba Sessões) |

- São uma previsão a partir das telas [NC]: o app ainda não existe. Se uma consulta do Flutter pedir outro índice, o erro do Firestore diz qual. **Acrescentar no arquivo e publicar pela CLI**, não criar à mão no console, para o arquivo continuar sendo a fonte da verdade.
- Conferido pela CLI (`firebase firestore:indexes`) em 25/10/2026: os 3 índices estão no projeto.

## 5. Decisões do usuário

| Tema | Decisão | Data |
|---|---|---|
| E-mail verificado | **Exigido.** Antes da verificação, o app só cria o próprio `users/{uid}` | 22/10 |
| Finalizar o dia (RF14) | **Pelo app** | 22/10 |
| Versão do aceite | **Precisa ser a vigente** (`legalDocuments/current`) | 22/10 |
| `legalDocuments` | Leitura pública | 22/10 |
| Confirmação de idade | **Data de nascimento** (`birthDate`), não editável pelo app | 22/10 |
| Idioma | Não guardar | 22/10 |
| Semana | **Domingo a sábado** | 22/10 |
| Plano principal | `users.primaryPlanId` | 22/10 |
| Pausa | Vale a partir de hoje (se o dia não foi finalizado); retomar também | 22/10 |
| Início do plano | Até 7 dias para trás | 22/10 |
| Validação antes do deploy | Emulador uma vez antes de cada deploy (opção B) | 24/10 |
| Cronômetro em andamento | **No aparelho**; a sessão vai ao Firestore só ao encerrar | 24/10 |
| Tópico da sessão | **Disciplina cadastrada** (`subjectId`) | 24/10 |
| Aviso de entrega da tarefa | 1 hora, 1 dia, 1 semana antes ou personalizado | 24/10 |
| Status de entrega e notas da tarefa | Fora do MVP | 24/10 |
| Pontos, conquistas e dias | **Pelo app, sem Cloud Function.** Pendência: em uma evolução do app, levar os pontos para funções no servidor | 24/10 |
| Notificações | **Locais.** Saem `devices`, `notificationLog` e preferências de aviso no Firestore. A decisão anterior "o dono lê o `notificationLog`" deixou de existir | 24/10 |
| Excluir conta | **Pelo app** (pede login de novo, apaga tudo e por fim a conta do Auth) | 24/10 |
| Login Google com menos de 16 | O app **apaga na hora** a conta vazia que o Auth criou | 24/10 |
| Catálogo de medalhas | **9 medalhas** (seção 4), com sequências de 7, 14, 21 e 30 dias; "Semana em dia" removida por repetir "7 dias seguidos". Acima do "≤ 8 no início" do design system | 24/10 |
| Teste no aparelho | Só depois da criação da seção Auth no app | 24/10 |
| Tópicos | **Tópicos próprios de cada plano** (`topics`), vários por matéria; podem reaproveitar uma matéria ou ser novos. A sessão marca `topicId` (substitui a decisão de 24/10, "tópico = disciplina") | 25/10 |
| Aviso noturno do plano | Fixo às **21h**, no app; sem campo no banco | 25/10 |
| Nível | **A cada 20 pontos, sobe um nível**: nível = pontos ÷ 20 (parte inteira) + 1. Regra do app | 25/10 |
| Disciplina | Usuário escolhe **ícone e cor** (paleta fixa) | 25/10 |
| Situação da entrega da tarefa | **Entra no MVP**: Não iniciada, Em andamento, Entregue, Aguardando correção | 25/10 |

Itens do Perfil aprovados (22/10): editar nome, nível e conquistas, privacidade e dados (Termos, Política, pedir cópia dos dados, contato), alterar senha (só e-mail e senha), Sobre (versão e licenças), sair, excluir conta.

## 6. Limites conhecidos das regras

- **Pontos e cálculos do app:** as regras validam tipos e limites, não a conta. Ver princípio 2.
- **Listas:** as regras não percorrem os itens de `pauses`; validam só o tipo e o tamanho.
- **Pausas, semana e fuso:** as regras não conferem se a pausa começou hoje, a contagem do "× por semana" nem se `day` bate com `startAt` no fuso do usuário. É lógica do app.
- **Coerência entre sessão e dia:** as regras não conferem se `days.doneMinutes` é a soma das sessões.
- **Exclusão pelo app:** se o app fechar no meio, ficam dados parciais até o próximo login, quando o app retoma. As regras não conferem se as subcoleções estão vazias antes de apagar o usuário.
- **Leituras extras (cobradas):** criar sessão ou dia (`exists` + `get` do plano, para checar o status), criar tópico ou versão (`getAfter` do plano), alterar `primaryPlanId`, apagar plano, criar conquista, aceite (`legalDocuments/current`) e as exclusões com "excluindo". Se o `exists` e o `get` do mesmo plano na mesma requisição contam como uma leitura só: [NC].
- **Plano em exclusão:** update de sessão e de dia continua permitido num plano `deleting` (bloquear custaria uma leitura a mais em toda gravação). Fica limitado à janela de 7 dias e não reabre o histórico.
- **Plano recriado com o mesmo id:** se o app apagar o documento do plano antes das subcoleções, sessões e dias órfãos continuam no banco; um plano novo criado com o mesmo id passaria a enxergá-los. O app deve usar ids automáticos para planos novos e apagar o plano por último (seção 7, item 11).

## 7. Pendências para outras sessões

O Flutter e o design estão pausados até o fim da configuração do Firebase (decisão de 24/10). Esta lista é para quando voltarem; nenhuma mensagem foi enviada.

**nexo-flutter (quando o app ligar o Firestore):**
1. Usar os nomes e formatos da seção 4. Inteiros: `dailyGoalMinutes`, `durationSeconds`, `doneMinutes`, `reminderMinutesBefore`, `overloadThreshold`, `points`.
2. Carimbos com `FieldValue.serverTimestamp()`: `createdAt`, `updatedAt`, `consents.acceptedAt`, `completedAt`, `finalizedAt`, `earnedAt`, `deletionRequestedAt`.
3. Cadastro: criar `users/{uid}` com `displayName`, `birthDate`, `timeZone` e `consents` (versões de `legalDocuments/current`). Depois do "Já confirmei": `reload()` + `getIdToken(true)`.
4. **Login Google com menos de 16 anos:** na 03b, ao recusar a idade, apagar na hora a conta do Auth (`currentUser.delete()`; o login é recente, então o Firebase permite) e voltar ao Login.
5. Criar plano: plano + versão inicial (`effectiveFrom` = início) + `primaryPlanId` (se for o principal) num lote só.
6. Cronômetro: guardar o início no aparelho; gravar a sessão só ao encerrar; dividir à meia-noite (fuso do usuário); gravar a sessão e atualizar `days/{data}.doneMinutes` no mesmo lote.
7. Calcular no app: meta, status e pontos de cada dia; totais da Visão geral e do Relatório; sequências; nível; contagens das disciplinas; "Atrasada".
8. Pontos: +1/−1 na tarefa; 5/3/7/0 no dia (com os ajustes de Desfazer, RF16 e edições dentro da janela). Gravar em `users.points`.
9. Conquistas: gravar `achievements/{id}` com `earnedAt` quando o critério do catálogo for atingido.
10. Notificações locais: lembrete diário do plano, aviso noturno **às 21h** se a meta não estiver completa, aviso 7 dias antes do fim do plano, aviso de entrega da tarefa (`reminderMinutesBefore`), limite de 1 aviso por plano/dia. Preferências de silêncio ficam no aparelho.
13. Nível: pontos ÷ 20 (parte inteira) + 1; a barra do Nexo/LevelProgress mostra "pontos atuais / 20" dentro do nível.
14. Tópicos do plano: criar, renomear e apagar em `plans/{id}/topics`; ao criar, oferecer as matérias existentes ou um tópico novo. A sessão grava `topicId`.
15. Tarefa: `deliveryStatus` coerente com `completed` (concluir → "Entregue"; reabrir → "Em andamento", no mesmo gravar).
11. Excluir plano: confirmar com o usuário → `status: "deleting"` (sem volta: depois disso o plano não aceita update nem filhos novos) → apagar sessões, dias, tópicos e versões em lotes → limpar `primaryPlanId` e apagar o plano. Planos novos sempre com id automático.
12. Excluir conta: pedir login de novo → `deletionRequestedAt` → apagar planos (como no item 11), tarefas, disciplinas, objetivos e conquistas → apagar `users/{uid}` → `currentUser.delete()`. Retomar no próximo login se parar no meio.

**Prototipação (quando o design voltar):**
1. Tela de detalhe da tarefa com o aviso de entrega (1 h, 1 dia, 1 semana, personalizado) e a **situação da entrega** (Não iniciada, Em andamento, Entregue, Aguardando correção) na Tag/Status.
2. Perfil com os itens aprovados, incluindo "Excluir conta" e o limite de sobrecarga (tarefas por dia).
3. Divergência a registrar no `ca7IW`: o item 11 diz que uma Cloud Function recalcula o dia e fecha os dias à meia-noite; o item 10 fala em FCM. Agora o app faz os dois (sem Function, notificações locais).
4. Nexo/Achievement e a documentação "07 / Achievement" dizem "≤ 8 medalhas no início" e dão "Semana em dia" como exemplo. O usuário decidiu por **9**, sem "Semana em dia" (24/10/2026): atualizar o texto e desenhar as 9 com os ícones da seção 4.
5. **Tópicos do plano:** gerenciar tópicos no Novo plano/detalhe do plano (reaproveitar matéria ou criar novo); na tela 10 Registrar horas, trocar "Escolha uma disciplina cadastrada" por "Escolha um tópico do plano".
6. **Disciplina com cor:** definir a paleta fixa de cores (com contraste nos dois temas) e desenhar a tela de criar/editar disciplina (nome, ícone, cor). Hoje o design marca "cor por disciplina" como Future.

**Dados e legal:** o inventário fala em "Tópico (texto livre)" na sessão; agora é um tópico do plano (nome digitado pelo usuário, ligado ou não a uma matéria). O inventário também dizia "cor por disciplina = Future" e "status de entrega = S"; os dois entraram no MVP (25/10). A Política já descreve notificações locais (confirmado pela sessão nexo-dados-legal em 22/10).

**Histórico de notificações (decisão do usuário de 04/11/2026; entra no bloco de integração com o Firebase):**

Painel aberto pelo sino no topo das abas, com os avisos dos últimos 30 dias. O design é da sessão de prototipação; os itens abaixo ficam para quando o app ligar o Firestore.

1. **Regras (sessão das regras):** coleção nova `users/{uid}/notifications`, só do dono com e-mail verificado.
   - Contrato a definir. Proposta: `type` (`dueSoon`, `overdue`, `dailyGoal`, `achievement`), o item ligado (`taskId`, `planId` + `day` ou `achievementId`), `createdAt` (servidor) e `readAt` (servidor ou null).
   - **Sem campo de expiração próprio** (decisão do usuário de 04/11/2026: "opção a, createdAt + 30 dias"). O TTL usa o próprio `createdAt` com deslocamento de 30 dias. Por isso as regras devem exigir `createdAt` **obrigatório e igual a `request.time`** (data/hora do servidor) no create, e imutável no update: documento sem esse campo, ou com outro tipo, nunca expira.
   - No update, só `readAt` muda. Testes no `firestore_tests/` e índice por `createdAt` decrescente.
2. **Quem grava:** o app, sem Cloud Function. O aviso entra no histórico quando o app detecta o evento, ou seja, quando é aberto; a notificação local continua saindo na hora certa. Id fixo por evento (ex.: tarefa + tipo) para não duplicar.
3. **Leitura:** um ícone no painel marca todos os avisos como lidos. Abrir o painel não marca nada. Ainda falta decidir se tocar num aviso o marca como lido.
4. **Excluir conta (item 12 da lista do nexo-flutter):** incluir `notifications` na limpeza, e nas regras liberar o delete com `userDeleting()` ou sempre para o dono.
5. **Guarda de 30 dias:** apagar sozinho pelo TTL do Firestore (`firebase-setup.md` §11, A13–A15). Política criada pelo usuário no console: collection group `notifications`, campo `createdAt`, deslocamento de 30 dias. O TTL apaga com atraso (não no minuto exato): o app filtra os avisos com mais de 30 dias ao exibir [NC: prazo de remoção do TTL].
6. **LGPD:** nova categoria no inventário e na Política (`docs/legal/pendencias.md`, B13).

**Futuro (evolução do app):** levar o cálculo de pontos para funções no servidor (decisão do usuário de 24/10).

## 8. Publicação (só com autorização explícita do usuário)

**24/10/2026: v0.5 publicada** (substituiu o bloqueio total do console). Passos 1 e 2 feitos. Passo 3: **feito** (`legalDocuments/current` conferido pela leitura pública da API; `achievementsCatalog` com 9 medalhas conferido pela consulta do console). Passo 4: **só depois da criação da seção Auth no app** (decisão do usuário de 24/10/2026).

Ordem:
1. **Testes no emulador**, uma vez (seção 2), todos passando. Encerrar o processo Java que fica na porta 8080.
2. **Deploy**, a partir de `app/`:

   ```bash
   firebase deploy --only firestore:rules,firestore:indexes --project nexo-app-gestao-f97bb
   ```

   - As regras publicadas pela CLI **sobrescrevem** as do console [C]. A propagação leva alguns minutos [C].
   - Se o arquivo tiver erro de sintaxe, o deploy é recusado e as regras atuais continuam [NC: comportamento da CLI].
3. **Console (usuário):** criar `legalDocuments/current` com `termsVersion` e `privacyVersion`, e o `achievementsCatalog` com as medalhas. Sem o `current`, nenhum cadastro passa.
4. **Aparelho físico:** testes de uso. O projeto é único (F2): o aparelho grava no mesmo banco dos usuários reais.

Para voltar atrás: o console guarda o histórico de versões das regras; dá para republicar o bloqueio total.

Alternativas avaliadas e não escolhidas para validar: Rules Playground do console (manual; a doc oficial não confirma suporte a `email_verified`, carimbo do servidor e lotes) e "só deploy + aparelho".

## 9. Referências oficiais

- Regras e condições: https://firebase.google.com/docs/firestore/security/rules-conditions
- Linguagem (Map, List, `diff`, `affectedKeys`, `getAfter`): https://firebase.google.com/docs/reference/rules/rules
- Dados por usuário: https://firebase.google.com/docs/firestore/security/rules-query
- Testes com o emulador: https://firebase.google.com/docs/rules/unit-tests
- Rules Playground: https://firebase.google.com/docs/rules/simulator
- Projetos `demo-`: https://firebase.google.com/docs/emulator-suite/connect_firestore
