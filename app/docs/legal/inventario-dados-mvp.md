# Nexo · Inventário de dados do MVP (aprovado)

Sessão: nexo-dados-legal. Criado em 2026-10-20, atualizado em 2026-10-22 (v0.2). Status: **aprovado pelo usuário** (decisões D1–D4 em 20/10; atualizações de 22/10 abaixo). Cópia oficial: `D:\Dev\Nexo\docs\legal\inventario-dados-mvp.md`.
Fontes lidas (somente leitura): `nexo.app.pen` (17 telas do fluxo de entrada) e, via import, `nexo.lib.pen`: `ca7IW` Regras e requisitos, `oXRSc` Fluxo do Plano de ação, Governança `ixE2I`, Capa, documentação 08 Content e 09 Nexo Specific, `context` dos componentes. Desde a v0.2, também `docs/backend/firestore-rules.md` (contrato de campos, seções 4 e 5) e `docs/legal/pendencias.md` (decisões F1–F7).

Legenda da coluna **Fonte**: **C** = confirmado no design ou em decisão registrada · **S** = suposição (precisa de confirmação) · **D** = dado derivado (calculado pelo app/Cloud Function, não digitado).
Bases legais (LGPD, art. 7º): **Contrato** = execução de contrato (V) · **Obrigação** = obrigação legal/regulatória (II) · **Direitos** = exercício regular de direitos (VI) · **LI** = legítimo interesse (IX) · **Consent.** = consentimento (I).

Princípio adotado: **todo dado pessoal do usuário fica sob `users/{uid}`**, o que torna exclusão e exportação uma operação única por usuário.

## Decisões do usuário (20/10/2026)

| # | Decisão | Efeito no inventário |
|---|---|---|
| D1 | **Idade mínima: 16 anos** | Usuários de 16 e 17 anos são adolescentes (LGPD art. 14: tratamento no melhor interesse; ECA Digital, Lei 15.211/2025). A idade é conferida pela **data de nascimento** (atualização de 22/10). Os Termos proíbem uso por menores de 16. |
| D2 | **Telemetria: só Crashlytics** | Analytics **fora do MVP**. Sem eventos de uso nem localização aproximada. |
| D3 | **Controlador: pessoa física por enquanto** | Documentos sem CNPJ. O Marco Civil art. 15 (guarda de registros por 6 meses) se dirige a pessoa jurídica: o advogado confirma se é dispensado. Agente de pequeno porte (Res. CD/ANPD nº 2/2022) pode não precisar nomear encarregado, mas precisa de canal de contato; o advogado avalia se dados de adolescentes tornam o tratamento de "alto risco". |
| D4 | **Disciplinas e entregas entram no MVP** | A seção 9 e a coleção `subjects` ficam. |

## Atualizações (22/10/2026, aprovadas pelo usuário)

| # | Atualização | Origem |
|---|---|---|
| U1 | Idade conferida por **data de nascimento** (`birthDate`, AAAA-MM-DD), gravada só na criação; o app não altera, e a correção é pelo canal de contato | Regras de segurança, Q6 |
| U2 | **Nada da Apple e só Android** no MVP. Login: e-mail/senha + Google | F6, F7 |
| U3 | Idioma não é guardado (MVP só em pt-BR) | Regras de segurança |
| U4 | Aceite = versão dos Termos + versão da Política + data/hora do servidor, conferidas contra `legalDocuments/current` | Regras de segurança, Q3 |
| U5 | Modelo do aparelho e versão do SO ficam fora do Firestore (minimização); só aparecem nos relatórios do Crashlytics | Regras de segurança |
| U6 | App Check fora do MVP | F5 |
| U7 | Firestore em `southamerica-east1` | F3 |
| U8 | Retenção: Crashlytics 90 dias; backups até 7 dias | Pendências B3 + usuário |
| U9 | **Lembretes como notificação local** (agendada no aparelho), sem token FCM no servidor. A etapa 10 das regras ainda está em revisão: se voltar para FCM, revisar as seções 11 e 12 e a Política | Usuário |
| U10 | Novo aviso: tarefa com entrega próxima | Regras de segurança, etapa 6 |
| U11 | Exclusão de conta, cópia dos dados e acesso aos Termos e à Política ficam no **Perfil** | Regras de segurança, etapa 11 |

---

## 1. Conta (autenticação)

| Campo | Fonte | Origem | Obrig.? |
|---|---|---|---|
| uid | C | gerado (Firebase Auth) | sim |
| E-mail | C (Login, Cadastro) | usuário ou Google | sim |
| Senha | C | usuário; o Nexo nunca lê, só o Firebase Auth guarda o hash | só em e-mail/senha |
| Provedor (e-mail/senha ou Google) | C | gerado | sim |
| E-mail verificado | C (tela 05, obrigatória; Q1) | gerado | sim |
| Datas de criação e último login | S (o Auth registra sozinho) | gerado | sim |
| Tentativas de login / bloqueio temporário | C ("Muitas tentativas") | gerado (proteção do Auth) | sim |
| Aceite: `consents {termsVersion, privacyVersion, acceptedAt}` | C (Cadastro e 03b; U4) | usuário + servidor | sim |
| Data de nascimento (`birthDate`) | C (Cadastro e 03b; U1) | usuário | sim |

- **Google entrega:** nome, e-mail, URL da foto, ID Google. A foto não é guardada.
- **Finalidade:** criar e proteger a conta; conferir a idade mínima; e-mails transacionais (verificação, redefinição de senha).
- **Base legal:** Contrato; data de nascimento = Contrato (a base é para o advogado validar); segurança/antifraude = LI; registro do aceite = Direitos.
- **Retenção:** enquanto a conta existir. Registro de aceite: pode ser guardado após a exclusão pelo prazo de defesa (decisão do advogado).
- **Firebase:** Authentication + Firestore (`users/{uid}`). **Terceiros:** Google (operador e provedor de identidade).

## 2. Perfil e preferências

| Campo | Fonte | Origem | Obrig.? |
|---|---|---|---|
| Nome / como quer ser chamado (`displayName`) | C (Cadastro, 03b) | usuário ou Google | sim |
| Foto de perfil | **Não guardada** | — | — |
| Fuso horário (`timeZone`) | C (dias fecham "à meia-noite no fuso do usuário") | dispositivo | sim |
| ~~Idioma/região~~ | **Não guardado (U3)** | — | — |
| Tutorial já visto | C | gerado | não |
| Limite de "sobrecarregado" | C ("deve ser configurável"); etapa 11 em revisão | usuário | não (padrão do app) |
| Preferências de notificação (ligado, silêncio, aviso noturno) | C; etapa 10 em revisão | usuário | não |

- **Finalidade:** personalizar o app e calcular os dias corretamente. **Base:** Contrato.
- **Retenção:** enquanto a conta existir. **Firebase:** Firestore (`users/{uid}`). **Terceiros:** Google (operador).

## 3. Objetivo (entidade opcional)

| Campo | Fonte | Obrig.? |
|---|---|---|
| Nome | C (decisão do usuário: objetivo agrupa planos) | sim |
| Planos vinculados | C | — |
| Descrição, prazo | C (contrato v0.2 das regras, em revisão) | não |

- Texto livre escrito pelo usuário. **Base:** Contrato. **Firebase:** Firestore. **Retenção:** até o usuário excluir o objetivo ou a conta.

## 4. Plano de ação

| Campo | Fonte | Obrig.? |
|---|---|---|
| Nome (texto livre, ex.: "Concurso Banco do Brasil", "TCC") | C (RF01) | sim |
| Início e fim | C (RF01) | sim |
| Frequência: todos os dias, dias da semana ou X por semana | C (RF02) | sim |
| Meta diária (guardada em minutos) | C (RF01) | sim |
| Categoria e tópicos | C (RF03), **fora do MVP** pela lista "MVP × depois" | não |
| Status: ativo, pausado, concluído, encerrado antes, arquivado | C (RF05–06) | sim |
| Períodos de pausa | C (RF05) | — |
| Plano principal | C (RF07) | — |
| Lembrete diário: horário e liga/desliga | C (Novo plano) | não |
| Histórico de alterações com vigência (`scheduleVersions`) | C (RF04); contrato v0.2 | — |
| Objetivo vinculado | C | não |
| Totais: horas planejadas, horas realizadas, saldo | **D** | — |

- **Finalidade:** núcleo do serviço. **Base:** Contrato. **Firebase:** Firestore.
- **Retenção:** enquanto o plano existir. Arquivado continua guardado até o usuário excluir.

## 5. Sessão de foco e registro manual de horas

| Campo | Fonte | Obrig.? |
|---|---|---|
| Início, fim, duração | C (RF09) | sim |
| Origem: foco ou manual | C | sim |
| Pausas dentro da sessão | C (RF08) | — |
| Tópico (texto livre) | C (RF10) | não |
| Nota (texto livre, ex.: "Interpretação de texto — lista 4") | C (RF10) | não |
| Dia a que pertence (sessão que cruza a meia-noite é dividida pelo app) | C (RF13) | sim |

- O cronômetro funciona com o app fechado porque grava o horário de início, não porque roda em segundo plano. **Não há localização.**
- **Base:** Contrato. **Firebase:** Firestore. **Retenção:** até editar/excluir (RF12), excluir o plano ou excluir a conta.

## 6. Dia do plano (derivado)

| Campo | Fonte |
|---|---|
| Data (AAAA-MM-DD), meta do dia | C |
| Realizado | **D** (soma das sessões) |
| Finalizado (sim/não, quando) | C (RF14; Q2: o app finaliza) |
| Status: cumprido, com menos, com mais, não cumprido, folga | **D** |
| Pontos do dia | **D** |

- **Base:** Contrato. **Firebase:** Firestore (cálculo pelo app ou por Function, em revisão nas regras).

## 7. Progresso e gamificação (derivado)

| Campo | Fonte |
|---|---|
| Pontos totais e nível | **D** (1 por tarefa; 5/3/7/0 por dia de plano) |
| Sequência atual e maior sequência | **D** |
| Conquistas (qual e quando) | **D** (≤ 8 medalhas) |
| Relatório parcial e final | **D**; guardar ou recalcular = S |

- Não há ranking, comparação entre usuários nem decisão automática que afete direitos (o art. 20 da LGPD tem baixo risco aqui). A Política explica como pontos e níveis são calculados.
- **Base:** Contrato. **Firebase:** Firestore.

## 8. Tarefas

| Campo | Fonte | Obrig.? |
|---|---|---|
| Título (texto livre) | C (TaskItem) | sim |
| Disciplina | C (meta do TaskItem) | não |
| Prazo: data e hora | C (Nexo/Deadline) | não ("Sem prazo") |
| Prioridade: alta, média, baixa, nenhuma | C (Nexo/Priority) | sim (padrão "nenhuma") |
| Concluída + data de conclusão | C | — |
| Status de entrega | C (Tag/Status "no detalhe"); valores = S | não |
| Notas | C (contrato v0.2 das regras); tela de detalhe não desenhada | não |

- **Base:** Contrato. **Firebase:** Firestore (`users/{uid}/tasks`).

## 9. Disciplinas e entregas (no MVP, D4)

| Campo | Fonte |
|---|---|
| Nome da disciplina, ícone | C (Subject Item, AcademicProgress) |
| Entregas concluídas / total, próxima entrega | **D** (contagem das tarefas da disciplina) |
| Provas ("primeira prova organizada") | C como conceito; campo = S |

- **Sinal de público estudantil**, possivelmente adolescente (ver R1).
- Cor por disciplina é Future: não entra.

## 10. Calendário

- No MVP **não há entidade própria**: mostra prazos de tarefas e dias de plano (D). Carga/sobrecarregado = **D**.
- Integração com agendas externas é **Future**: **nenhum dado de agenda externa é lido no MVP**.

## 11. Notificações (locais, U9)

| Campo | Fonte | Obrig.? |
|---|---|---|
| Horário do lembrete diário (por plano) | C | não |
| Preferências de aviso (silêncio, aviso noturno) | C | não |
| Permissão de notificação do sistema | C (pedida pelo Android) | — |
| ~~Token FCM por dispositivo~~ | **Fora, enquanto os avisos forem locais (U9)** | — |
| ~~Último aviso enviado por plano/dia~~ | **Controle no aparelho, enquanto os avisos forem locais (U9)** | — |

- Avisos: lembrete diário do plano, aviso noturno se a meta não estiver completa, aviso 7 dias antes do fim do plano, aviso de tarefa com entrega próxima (U10). Limite de 1 por plano por dia.
- Lembretes que o usuário configura = funcionalidade, **Base:** Contrato (com a permissão do SO). **Marketing por push ou e-mail** = **Consent.**, separado e opcional (não há marketing no MVP).
- **Firebase:** nenhum serviço de envio (agendamento local). Os horários ficam no Firestore como preferência.

## 12. Dispositivo, segurança e telemetria

| Campo | Fonte | Serviço | Base |
|---|---|---|---|
| ~~Modelo, SO, versão do app, ID de instalação no Firestore~~ | **Fora (U5)** | — | — |
| Relatórios de falha (stack trace, modelo, versão do SO e do app, estado do aparelho, ID de instalação) | D2 | Crashlytics (retenção 90 dias) | LI |
| ~~Eventos de uso, ID da instância, localização aproximada~~ | **Fora do MVP (D2)** | ~~Analytics~~ | — |
| ~~Atestado do dispositivo contra abuso~~ | **Fora do MVP (U6)** | ~~App Check~~ | — |
| Registros de acesso: IP + data/hora | S (ver R9) | Auth/Functions | Obrigação (Marco Civil art. 15, se aplicável) |
| Cache local offline (dados digitados ficam no aparelho) | C ("Seus dados digitados ficam aqui") | Firestore offline / SDK | Contrato |

- **Sem identificador de publicidade (AAID)** e sem SDK de anúncios.

## 13. E-mails do sistema

- Verificação de e-mail e redefinição de senha: C (telas 04 e 05), enviados pelo Firebase Auth. **Base:** Contrato.
- Remetente no MVP: domínio padrão do projeto Firebase (domínio próprio em aberto, pendências B5).

## 14. Atendimento ao titular

- Canal: e-mail de contato do controlador (preenchido nos documentos v0.2) e as opções do **Perfil** (U11).

---

## Mapa conceitual de coleções do Firestore (só modelo, sem regras nem índices)

Para os nomes de campos e validações vigentes, a referência é `docs/backend/firestore-rules.md` (seção 4).

```
users/{uid}                                displayName, birthDate, consents {termsVersion, privacyVersion, acceptedAt}, timeZone, tutorialSeen, preferências, agregados (pontos, nível)
  goals/{goalId}                           objetivo (opcional)
  plans/{planId}                           configuração, status, isPrimary, goalId?, lembrete, totais (D), pausas
    scheduleVersions/{id}                  alterações com vigência (RF04)
    sessions/{sessionId}                   início, fim, duração, origem, tópico?, nota?, pausas
    days/{AAAA-MM-DD}                      meta, realizado (D), finalizado, status (D), pontos (D)
  tasks/{taskId}                           título, subjectId?, prazo?, prioridade, concluída, concluídaEm, notas?
  subjects/{subjectId}                     disciplina
  achievements/{achievementId}             conquistada em
  devices/{installationId}                 [só se a etapa 10 voltar para FCM]
  notificationLog/{id}                     [só se a etapa 10 voltar para FCM]
achievementsCatalog/{id}                   catálogo das medalhas (conteúdo do app, sem dado pessoal)
legalDocuments/current                     versões vigentes dos Termos e da Política
```

**Divergência registrada:** `ca7IW` (item 11) escreve `plans/{planId}/sessions` sem o prefixo `users/{uid}`. A decisão vigente é `users/{uid}/plans/{planId}/sessions` (pendências B6); o design continua com o caminho antigo.

---

## Riscos e decisões do usuário

| # | Tema | Por quê | Status |
|---|---|---|---|
| R1 | **Idade mínima** | Disciplinas, provas e entregas sugerem estudantes. LGPD art. 14 + Lei 15.211/2025 (ECA Digital) impõem regras extras para adolescentes. | **Decidido: 16+ por data de nascimento (D1, U1).** O advogado confirma se basta e define as salvaguardas para 16–17 anos. |
| R2 | **Transferência internacional** | Auth e Crashlytics processam fora do Brasil (Google); o Firestore fica em `southamerica-east1`. | Declarado na Política 7; o advogado valida o mecanismo (Res. CD/ANPD nº 19/2024). |
| R3 | **Analytics e Crashlytics** | Analytics coleta eventos e localização aproximada. | **Decidido: só Crashlytics (D2).** |
| R4 | **Exclusão de conta dentro do app** | Exigência do Google Play (inclusive link web para pedir exclusão). | Aprovada no Perfil (U11); falta a tela e o link web. |
| R5 | **Exportação de dados** (portabilidade, art. 18) | Direito do titular. | Pedido pelo Perfil ou por e-mail, resposta em até 15 dias. |
| R6 | **Login com Google × aceite dos Termos** | Quem entrava com Google criava conta sem o aceite. | **Resolvido:** tela 03b com aceite e data de nascimento. |
| R7 | **Verificação de e-mail com Google** | E-mails do Google já vêm verificados. | Confirmar no protótipo que a tela 05 só aparece para e-mail/senha. |
| R8 | **Texto livre** (nomes, descrições, tópicos, notas, tarefas) | O usuário pode escrever dados sensíveis (saúde, religião…). | A Política orienta a não incluir dados sensíveis; o Nexo não usa esse conteúdo para outro fim (sem IA, sem anúncios). |
| R9 | **Registros de acesso (Marco Civil, art. 15)** | Pessoa jurídica com fins econômicos deve guardar IP + data/hora por 6 meses. | Controlador pessoa física (D3): o advogado confirma se há dispensa. |
| R10 | **Controlador** | Pessoa física ou empresa muda a identificação, o foro e o R9. | **Decidido: pessoa física por enquanto (D3).** Revisar os documentos se abrir empresa. |
| R11 | **Prazo de exclusão e backups** | Backups guardam cópias por um tempo após a exclusão. | **Decidido: até 7 dias (U8).** |
| R12 | **Marketing** | Não há marketing no MVP. | Se houver, opt-in separado. |
| R13 | **Branding do botão Google** | O botão usa Manrope; o Google recomenda Roboto. | Fora do escopo legal; validar antes de publicar. |
| R14 | **Notificações locais × etapa 10** | A Política já descreve avisos locais, mas a etapa 10 das regras ainda está em revisão. | Se a decisão técnica for FCM, revisar a Política (3.5, 5, 6, 7, 11) e este inventário (11, 12). |
