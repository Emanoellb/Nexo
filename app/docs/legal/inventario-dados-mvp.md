# Nexo · Inventário de dados do MVP (aprovado)

Sessão: nexo-dados-legal. Criado em 2026-10-20 · v0.2 em 2026-10-22 · **v0.3 em 2026-11-07**. Status: base aprovada pelo usuário (D1–D4 em 20/10; U1–U11 em 22/10). A v0.3 alinha o inventário às regras do Firestore **v0.9** e às decisões de 24/10 a 07/11 (tabela "Atualizações de 07/11"), a pedido da sessão principal ("pode seguir com o legal", usuário, 07/11/2026).

Fontes: `app/docs/backend/firestore-rules.md` v0.9 (§3 princípios, §4 contrato de campos, §5 decisões, §7 pendências), `app/docs/backend/firebase-setup.md` §8 e §11, `AGENTS.md` §4–§5, `app/pubspec.yaml`, e as telas e regras do design lidas em 20/10 (`nexo.app.pen`, `ca7IW`, `oXRSc`).

Legenda da coluna **Fonte**: **C** = confirmado no contrato das regras, numa decisão registrada ou no design · **NC** = não confirmado (previsto, ainda não implementado ou não conferido) · **D** = dado derivado, calculado pelo app e não guardado.
Bases legais (LGPD, art. 7º): **Contrato** = execução de contrato (V) · **Obrigação** = obrigação legal/regulatória (II) · **Direitos** = exercício regular de direitos (VI) · **LI** = legítimo interesse (IX) · **Consent.** = consentimento (I).

Princípios:
- **Todo dado pessoal do usuário fica sob `users/{uid}`.** Exclusão e exportação são uma operação única por usuário.
- **Sem Cloud Functions no MVP** (24/10/2026): o app grava e calcula tudo; as regras validam.
- **Lista branca de campos:** o que não está no contrato das regras é negado no banco.

## Decisões do usuário (20/10/2026)

| # | Decisão | Efeito |
|---|---|---|
| D1 | **Idade mínima: 16 anos** | Conferida pela data de nascimento (U1). Usuários de 16 e 17 anos são adolescentes (LGPD art. 14; ECA Digital, Lei 15.211/2025) |
| D2 | **Telemetria: só Crashlytics** | Sem Analytics, sem eventos de uso, sem localização aproximada |
| D3 | **Controlador: pessoa física por enquanto** | Documentos sem CNPJ. Marco Civil art. 15 e obrigatoriedade do encarregado ficam com o advogado |
| D4 | **Disciplinas e entregas no MVP** | Coleção `subjects` e situação da entrega nas tarefas |

## Atualizações de 22/10/2026 (aprovadas pelo usuário)

U1 data de nascimento · U2 nada da Apple, só Android · U3 idioma não guardado · U4 aceite com versões + hora do servidor · U5 modelo e SO só no Crashlytics · U6 App Check fora do MVP · U7 Firestore em `southamerica-east1` · U8 Crashlytics 90 dias, backups 7 dias · U9 lembretes como notificação local · U10 aviso de entrega próxima · U11 opções de privacidade no Perfil.

## Atualizações de 07/11/2026 (v0.3)

| # | Atualização | Origem |
|---|---|---|
| V1 | **Notificações locais confirmadas** (24/10): sem FCM, sem `devices` e sem `notificationLog`. O risco R14 da v0.2 está fechado | `firestore-rules.md` §3 item 7, §5 |
| V2 | **Sem Cloud Functions**: dias, pontos e conquistas são calculados e gravados pelo app | `firestore-rules.md` §3 item 2 |
| V3 | **Histórico de notificações** em `users/{uid}/notifications`, guardado **30 dias** (TTL pelo `createdAt`) e apagado com a conta. Decidido em 04/11; contrato e regras ainda **não publicados** | `pendencias.md` B13; `firestore-rules.md` §7; `firebase-setup.md` A13–A15 |
| V4 | **Preferências só no aparelho**, nunca no banco: tema, "Ligar o Não perturbe ao focar", "Reduzir transparência" e preferências de silêncio | `firestore-rules.md` §4 (users) e §7 item 10 |
| V5 | Campos novos da v0.9: `tasks.remindersMinutesBefore` (até 3 avisos), `plans.studyTime` + `plans.reminderBefore`, `users.morningSummary`, `sessions.topicIds` (até 3 tópicos). Saíram: `plans.reminder`, `sessions.topicId`, `tasks.reminderMinutesBefore` | `firestore-rules.md` §4, v0.9 |
| V6 | **Tópicos do plano** (`plans/{id}/topics`): nome digitado + matéria opcional. Substituem o "tópico texto livre" da sessão | `firestore-rules.md` §4 (25/10) |
| V7 | **Saíram do MVP:** notas da tarefa, pausas dentro da sessão (só a duração líquida é guardada) e cor da disciplina (revertida em 04/11) | `firestore-rules.md` §4 e §5 |
| V8 | **Permissões e recursos do Android** previstos na Etapa 3c (lista abaixo, seção 12). Ainda **não conferidos no código** | Pedido da sessão principal, 07/11 |
| V9 | **Canal de contato:** e-mail do controlador. Telefone **não** entra nos documentos | Decisão do usuário, via sessão principal |
| V10 | **Terminologia neutra** (07/11): os planos servem a qualquer objetivo (estudo, treino, leitura…). Só a descrição do produto muda; dados e nomes de campos ficam iguais | Decisão do usuário, via sessão principal |
| V11 | **Um projeto Firebase só** (confirmado em 04/11): testes e usuários reais no mesmo banco. Nada muda nos documentos | `pendencias.md` B8 |

---

## 1. Conta (autenticação)

| Campo | Fonte | Origem | Obrig.? |
|---|---|---|---|
| uid | C | gerado (Firebase Auth) | sim |
| E-mail | C | usuário ou Google | sim |
| Senha | C | usuário; o Nexo nunca lê, só o Firebase Auth guarda o hash | só em e-mail/senha |
| Provedor (e-mail/senha ou Google) | C | gerado | sim |
| E-mail verificado | C (exigido para usar os dados) | gerado | sim |
| Datas de criação e último login | NC (o Auth registra sozinho) | gerado | sim |
| Tentativas de login / bloqueio temporário | C ("Muitas tentativas") | gerado (proteção do Auth) | sim |
| `birthDate` | C (Cadastro e 03b; não editável pelo app) | usuário | sim |
| `consents {termsVersion, privacyVersion, acceptedAt}` | C (versões iguais a `legalDocuments/current`) | usuário + servidor | sim |
| `deletionRequestedAt` | C (Excluir conta; sem volta) | app + servidor | não |

- **Google entrega:** nome, e-mail, URL da foto, ID Google. A foto não é guardada.
- **Login Google com menos de 16 anos:** o app apaga na hora a conta recém-criada no Auth.
- **Finalidade:** criar e proteger a conta; conferir a idade mínima; e-mails do sistema (verificação, redefinição de senha); executar a exclusão da conta.
- **Base legal:** Contrato; data de nascimento = Contrato (a validar com o advogado); segurança = LI; registro do aceite = Direitos.
- **Retenção:** enquanto a conta existir. Registro de aceite após a exclusão: prazo com o advogado.
- **Firebase:** Authentication + Firestore (`users/{uid}`). **Terceiros:** Google (operador e provedor de identidade).

## 2. Perfil e preferências guardadas na conta

| Campo | Fonte | Origem | Obrig.? |
|---|---|---|---|
| `displayName` | C | usuário ou Google | sim |
| `timeZone` | C (divisão à meia-noite e avisos) | aparelho | sim |
| `tutorialSeen` | C | gerado | não |
| `primaryPlanId` (plano principal) | C | usuário | não |
| `overloadThreshold` (limite de "sobrecarregado", tarefas por dia) | C | usuário | não (padrão 5 no app) |
| `morningSummary {enabled, time}` (aviso da manhã) | C (v0.9) | usuário | não (padrão ligado, 08:00) |
| `points` | C (o app soma e subtrai) | gerado pelo app | não |
| Foto de perfil, idioma | **Não guardados** | — | — |

- **Finalidade:** personalizar o app, calcular os dias e agendar avisos. **Base:** Contrato.
- **Retenção:** enquanto a conta existir. **Firebase:** Firestore (`users/{uid}`).

## 3. Objetivo (opcional)

| Campo | Fonte | Obrig.? |
|---|---|---|
| Nome | C | sim |
| Descrição | C (0–500) | não |
| Prazo | C | não |

- No máximo um objetivo por plano (07/11). **Base:** Contrato. **Retenção:** até o usuário excluir o objetivo ou a conta.

## 4. Plano de ação

| Campo | Fonte | Obrig.? |
|---|---|---|
| Nome (texto livre) | C | sim |
| Início e fim (até 2 anos) | C | sim |
| Frequência: todos os dias, dias da semana ou × por semana | C | sim |
| Meta diária (minutos) | C | sim |
| Status: ativo, pausado, concluído, encerrado antes, arquivado, excluindo | C | sim |
| Pausas `{start, end}` | C | não |
| Data de encerramento antecipado (`endedOn`) | C | não |
| Objetivo (`goalId`) | C | não |
| Horário do plano (`studyTime`) | C (v0.9) | não (padrão 19:00) |
| Avisar antes do horário (`reminderBefore`) | C (v0.9) | não (padrão ligado, 15 min) |
| Histórico de configurações (`scheduleVersions`) | C | — |
| Totais, saldo, relatórios | **D** | — |

- Categoria do plano (RF03) fica fora do MVP. **Base:** Contrato. **Firebase:** Firestore.
- **Retenção:** enquanto o plano existir. Excluir o plano apaga sessões, dias, tópicos e versões.

## 5. Tópicos do plano

| Campo | Fonte | Obrig.? |
|---|---|---|
| Nome (texto livre) | C | sim |
| Disciplina ligada (`subjectId`) | C | não |

- **Base:** Contrato. **Retenção:** até o usuário apagar o tópico, o plano ou a conta.

## 6. Sessão de foco e registro manual de tempo

| Campo | Fonte | Obrig.? |
|---|---|---|
| Início e fim | C | sim |
| Duração líquida (sem pausas) | C | sim |
| Origem: foco ou manual | C | sim |
| Dia a que pertence (dividida à meia-noite) | C | sim |
| Tópicos (`topicIds`, até 3) | C (v0.9) | não |
| Nota (texto livre, até 500) | C | não |

- **O cronômetro em andamento fica no aparelho:** só o horário de início é guardado localmente; a sessão vai ao banco ao encerrar. As pausas não são guardadas.
- Tempo por tópico = duração ÷ número de tópicos (**D**).
- **Base:** Contrato. **Retenção:** até editar/excluir (janela de 7 dias), excluir o plano ou a conta.

## 7. Dia do plano

| Campo | Fonte |
|---|---|
| Data (id do documento) | C |
| Minutos realizados (`doneMinutes`) | C (gravado pelo app, soma das sessões) |
| Finalização (`finalizedAt`) | C |
| Meta, status e pontos do dia | **D** (não guardados) |

- **Base:** Contrato. **Retenção:** até excluir o plano ou a conta.

## 8. Progresso e conquistas

| Campo | Fonte |
|---|---|
| Pontos (`users.points`) | C (gravado pelo app) |
| Nível, sequências, relatórios | **D** |
| Conquistas (`achievements/{id}.earnedAt`) | C (9 medalhas) |

- Sem ranking nem comparação entre usuários. As regras validam formato e limites, não a conta dos pontos (risco baixo: só afeta o próprio usuário).
- **Base:** Contrato.

## 9. Tarefas

| Campo | Fonte | Obrig.? |
|---|---|---|
| Título (texto livre) | C | sim |
| Prioridade | C | sim |
| Concluída + data de conclusão | C | sim |
| Disciplina | C | não |
| Prazo | C | não |
| Avisos de entrega (`remindersMinutesBefore`, até 3) | C (v0.9) | não |
| Situação da entrega (Não iniciada, Em andamento, Entregue, Aguardando correção) | C | não |
| ~~Notas~~ | **Fora do MVP (V7)** | — |

- "Atrasada" é **D**. **Base:** Contrato. **Firebase:** Firestore (`users/{uid}/tasks`).

## 10. Disciplinas

| Campo | Fonte |
|---|---|
| Nome e ícone | C |
| ~~Cor~~ | **Fora do MVP (V7)** |
| Entregas concluídas / total, próxima entrega | **D** |

## 11. Histórico de notificações (V3)

| Campo | Fonte | Obrig.? |
|---|---|---|
| Tipo: entrega próxima, tarefa atrasada, meta do dia, conquista | NC (proposta de contrato) | sim |
| Item ligado (tarefa, plano + dia ou conquista) | NC | sim |
| `createdAt` (servidor) | C (decisão; base do TTL) | sim |
| `readAt` (lido) | NC | não |

- **Finalidade:** mostrar no painel do sino os avisos dos últimos 30 dias. **Base:** Contrato.
- **Retenção:** **30 dias**, apagados pelo TTL do Firestore (a remoção costuma acontecer em até 24 h depois do vencimento [C, doc do TTL]); o app esconde os vencidos. Apagados também com a conta.
- **Pendências:** contrato e regras não publicados; política de TTL só será criada depois do primeiro aviso gravado (`firebase-setup.md` A13). Enquanto o TTL não existir, a promessa de 30 dias da Política não é cumprida automaticamente.

## 12. Notificações locais, preferências do aparelho e permissões do Android

**Avisos agendados no aparelho** (sem servidor, sem token):

- aviso antes do horário do plano (`studyTime` − `reminderBefore`);
- aviso da manhã (`morningSummary`);
- aviso às 21h se a meta do dia não estiver completa;
- aviso 7 dias antes do fim do plano;
- avisos de entrega da tarefa (até 3 por tarefa);
- limite de 1 aviso por plano por dia.

**Preferências só no aparelho (V4):** tema (Sistema · Claro · Escuro), "Ligar o Não perturbe ao focar", "Reduzir transparência", preferências de silêncio. Reinstalando o app, voltam ao padrão.

**Permissões e recursos do Android (V8, todos NC até a Etapa 3c):**

| Recurso | Para quê | Coleta dado? |
|---|---|---|
| Notificações | Mostrar os avisos acima | Não |
| Acesso ao "Não perturbe" (`ACCESS_NOTIFICATION_POLICY`), opcional, pedido uma vez | Ligar e desligar o modo durante o foco, se o usuário ativar a opção | Não lê notificações nem contatos |
| Notificação fixa do cronômetro (provável serviço em primeiro plano no Android 14) | Mostrar o foco em andamento com o app fechado | Não |
| Checagem de conexão (`connectivity_plus`) | Avisar quando está sem internet | Não |
| Vibração | Retorno leve ao concluir | Não |
| Agendamento de alarmes exatos | **A confirmar** se o pacote de notificações locais vai pedir | Não |

- **Base:** Contrato. A lista final sai do `AndroidManifest.xml` depois da 3c e alimenta a seção "Segurança dos dados" do Google Play.

## 13. Dados técnicos e cache local

| Campo | Fonte | Serviço | Base |
|---|---|---|---|
| Relatórios de falha (erro, modelo, versões do SO e do app, estado do aparelho, ID de instalação) | C (D2) | Crashlytics, 90 dias, coleta desligada em debug | LI |
| Registros de acesso: IP + data/hora | NC (R9) | Auth | Obrigação, se aplicável |
| Cache offline do Firestore | C | SDK no aparelho | Contrato |
| ~~Analytics, App Check, token FCM, `devices`~~ | **Fora do MVP** | — | — |

- Relatórios do Crashlytics não podem conter e-mail, nome nem texto livre (`AGENTS.md` §9). Sem identificador de publicidade e sem SDK de anúncios.

## 14. E-mails do sistema e atendimento

- Verificação de e-mail e redefinição de senha, pelo Firebase Auth (página padrão; remetente do domínio do projeto). **Base:** Contrato.
- Atendimento: **e-mail** do controlador e opções do Perfil (Termos, Política, pedir cópia dos dados, contato, excluir conta). Telefone fora dos documentos (V9).

---

## Mapa de coleções do Firestore

Nomes e validações vigentes: `app/docs/backend/firestore-rules.md` §4 (v0.9).

```
users/{uid}                    displayName, birthDate, consents, timeZone, tutorialSeen, primaryPlanId,
                               overloadThreshold, morningSummary, points, deletionRequestedAt, createdAt, updatedAt
  plans/{planId}               name, startDate, endDate, frequency, dailyGoalMinutes, status, pauses, endedOn,
                               goalId, studyTime, reminderBefore, createdAt, updatedAt
    scheduleVersions/{id}      effectiveFrom, frequency, dailyGoalMinutes, createdAt
    topics/{topicId}           name, subjectId, createdAt, updatedAt
    sessions/{sessionId}       startAt, endAt, durationSeconds, source, day, topicIds, note, createdAt, updatedAt
    days/{AAAA-MM-DD}          doneMinutes, finalizedAt, createdAt, updatedAt
  tasks/{taskId}               title, priority, completed, completedAt, subjectId, dueAt, remindersMinutesBefore,
                               deliveryStatus, createdAt, updatedAt
  subjects/{subjectId}         name, icon, createdAt, updatedAt
  goals/{goalId}               name, description, deadline, createdAt, updatedAt
  achievements/{achievementId} earnedAt
  notifications/{id}           [V3, contrato a publicar] type, item ligado, createdAt, readAt
achievementsCatalog/{id}       conteúdo do app (9 medalhas), sem dado pessoal
legalDocuments/current         termsVersion, privacyVersion
```

---

## Riscos e decisões

| # | Tema | Status |
|---|---|---|
| R1 | Idade mínima 16+ por data de nascimento | Decidido (D1, U1). O advogado confirma se basta e as salvaguardas para 16–17 anos |
| R2 | Transferência internacional (Auth e Crashlytics fora do Brasil) | Declarado na Política 7; mecanismo com o advogado |
| R3 | Analytics | Decidido: fora (D2) |
| R4 | Excluir conta no app + link web (Google Play) | Fluxo decidido (pelo app); falta a tela e o link web |
| R5 | Portabilidade | Pelo Perfil ou e-mail, resposta em até 15 dias |
| R8 | Texto livre (nomes, descrições, tópicos, notas da sessão, títulos) | A Política orienta a não incluir dados sensíveis |
| R9 | Registros de acesso (Marco Civil art. 15) | Com o advogado (D3) |
| R11 | Backups | Decidido: 7 dias |
| R12 | Marketing | Não há no MVP |
| R14 | ~~Notificações locais × etapa 10~~ | **Fechado (V1):** locais, decidido em 24/10 |
| R15 | Histórico de notificações sem TTL ativo | A política de TTL só nasce depois do primeiro aviso gravado (A13). Até lá, avisos não somem sozinhos aos 30 dias |
| R16 | Permissões do Android ainda não conferidas | Conferir o `AndroidManifest.xml` depois da 3c e ajustar a Política 11 e o formulário do Google Play |
| R17 | Vigência vencida | A v0.2 previa 01/11/2026 e não foi publicada. Os textos continuam rascunho até o advogado |
