# Pendências dos documentos legais do Nexo (MVP)

Data: 2026-10-20 · atualizado em 2026-10-22. Documentos: `termos-de-uso.md` e `politica-de-privacidade.md` (rascunhos **v0.2**). Base aprovada: `inventario-dados-mvp.md`.

## Mudanças da v0.2 (22/10/2026, aprovadas pelo usuário)

1. Idade conferida pela **data de nascimento** (`users/{uid}.birthDate`), que o app não altera depois; a correção é pelo contato (decisão Q6 da sessão de regras de segurança).
2. **Nada da Apple** e **só Android** no MVP (F6/F7): login com e-mail/senha + Google.
3. Idioma não é guardado.
4. Modelo do aparelho e versão do sistema só nos relatórios do Crashlytics; sem coleção `devices` com esses dados.
5. App Check fora do MVP (F5): o item saiu da Política.
6. Firestore em `southamerica-east1` (F3).
7. Retenção: Crashlytics 90 dias; **backups até 7 dias** (decisão do usuário).
8. Controlador, contato, DPO e vigência (01/11/2026) preenchidos pelo usuário.
9. Excluir conta, cópia dos dados, Termos e Política ficam no **Perfil** (itens aprovados da etapa 11).
10. Novo aviso: tarefa com entrega próxima.
11. Objetivo com descrição e prazo opcionais; tarefa com notas.
12. **Lembretes descritos como notificações locais** (sem token FCM no servidor), por decisão do usuário, antes da etapa 10 fechar. **Se a etapa 10 voltar para FCM, as seções 3.5, 5, 6, 7 e 11 da Política precisam voltar a citar o token e o Cloud Messaging.**
13. Preço: **gratuito no MVP**.

## Decisões já tomadas pelo usuário

| # | Decisão |
|---|---|
| D1 | Idade mínima de 16 anos |
| D2 | Telemetria do MVP: só Firebase Crashlytics (sem Analytics) |
| D3 | Controlador: pessoa física por enquanto |
| D4 | Disciplinas e entregas entram no MVP |

## A. Informações para preencher (usuário)

| Marcador | Onde aparece | Status |
|---|---|---|
| Nome do controlador | Termos 1, 11, 16 · Política 1, 14 | **Preenchido na v0.2** |
| E-mail de contato | Termos e Política | **Preenchido na v0.2** |
| E-mail do encarregado (DPO) | Política 1 | **Preenchido** (mesmo e-mail); obrigatoriedade com o advogado (D2) |
| Data de vigência | Topo dos dois documentos | **01/11/2026**. Atenção: sobram poucos dias para a revisão jurídica |
| `[FORO]` | Termos 15 | Aberto |
| Modelo de preço | Termos 9 | **Gratuito no MVP** |
| Caminho no app | Termos 12 · Política 10 | **Perfil** |
| `[URL DA PÁGINA DE EXCLUSÃO]` | Termos 12 · Política 10 | Aberto (exigência do Google Play: link web para pedir exclusão) |
| Prazo de eliminação dos backups | Política 9 | **Até 7 dias** |
| `[PRAZO]` de aviso de fim do serviço | Termos 12 | Aberto |

## B. Decisões técnicas (sessões de infra/backend)

Guia de configuração: `docs/backend/firebase-setup.md` (decisões F1–F7, 21/10/2026).

1. Região do Firestore (`[REGIÃO DO FIRESTORE]`, Política 7). **Decidido em 21/10/2026: `southamerica-east1` (São Paulo, regional)** (F3). A região não muda depois de criado o banco.
2. Uso ou não do Firebase App Check (Política 3.5). **Decidido em 21/10/2026: depois do MVP** (F5). A Política 3.5 deve dizer que o App Check não é usado no MVP. Recomendação do guia: ativar o SDK antes da primeira versão pública, porque impor o App Check depois quebra versões antigas.
3. Prazo de retenção dos relatórios do Crashlytics e dos backups (Política 9). **Parcial:**
   - Crashlytics: **90 dias** (fixo, documentação oficial).
   - Backups do Firestore: **decidido em 22/10/2026: até 7 dias** (já na Política 9). A configuração alvo é backup diário com retenção de 7 dias e PITR desligado. **Configurado em 24/10/2026:** backup diário com retenção de 7 dias. O agendamento semanal de 98 dias, criado com o banco, foi apagado. O backup de 23/10 foi apagado pelo usuário (verificado em 24/10/2026).
4. Como guardar o aceite: versão + data/hora em `users/{uid}`, mais uma coleção `legalDocuments` com as versões. **Decidido** (versão + data/hora em `users/{uid}`). As regras de `legalDocuments` ficam com a sessão de segurança.
5. Domínio de envio de e-mails registrado na Apple, para alcançar e-mails de retransmissão. **Não se aplica ao MVP** (sem Apple, item 11). Domínio de envio (R4 da spec de redefinição): **decidido em 24/10/2026: sem domínio próprio no MVP**; o remetente fica `noreply@nexo-app-gestao-f97bb.firebaseapp.com`. Fica como pendência para quando o projeto crescer.
6. Caminho das sessões no Firestore: `ca7IW` (item 11) escreve `plans/{planId}/sessions` sem `users/{uid}` (divergência registrada). **Resolvido pela decisão "todo dado do usuário fica sob `users/{uid}`":** `users/{uid}/plans/{planId}/sessions`. O design (`ca7IW`) continua com o caminho antigo, e a divergência fica registrada.
7. **Nome do pacote Android definitivo (`applicationId`; "Nome do pacote do Android" no console):** **decidido em 22/10/2026: `dev.emanoelbarbosa.nexo`** (F1). O app já está registrado no Firebase, e o código Android já usa esse pacote (verificado em 22/10/2026).
8. **Ambientes:** ~~um projeto Firebase só (21/10/2026)~~ **decidido em 26/10/2026: separar desenvolvimento e produção agora, em dois projetos Firebase** (F2). A definição de qual projeto fica com cada papel está em `firebase-setup.md` §14.
   - Efeito nos documentos legais (a confirmar com a sessão de dados e legal): a Política não cita o Project ID, e os dois projetos ficam em `southamerica-east1`. Em princípio não muda nada, desde que o projeto de desenvolvimento só tenha dados de teste do próprio desenvolvedor.
   - O remetente dos e-mails (item 5 e item 12) passa a ser o do projeto de **produção**.
9. **Plano do Firebase:** **Blaze, contratado pelo usuário em 21/10/2026** (F4). Falta o alerta de orçamento (que só avisa; não limita o gasto). Fecha o R6 da spec de redefinição de senha.
10. **Plataforma do MVP:** **decidido em 21/10/2026: só Android** (F6).
11. **Apple:** **decidido em 21/10/2026: nada da Apple no MVP** (F7). Isso exclui Sign in with Apple, Apple Developer Program e iOS. O login do MVP é e-mail/senha + Google.
    - Efeito nos documentos legais: **aplicado na v0.2** (Termos, Política e inventário sem Apple).
    - Efeito no design: os botões e fluxos de login Apple saem do MVP (sessão de prototipação).
    - Efeito na spec de redefinição de senha: ela ainda cita a Apple (Email Sources, testes). Revisar com a sessão nexo-reset-senha.
12. **Projeto Firebase:** criado pelo usuário. Nome `nexo-app-gestao`, **Project ID `nexo-app-gestao-f97bb`** (permanente). Esse ID aparece no remetente dos e-mails enquanto não houver domínio próprio.
13. **Histórico de notificações:** **decidido em 04/11/2026**, entra no bloco de integração. Os avisos (entrega próxima, tarefa atrasada, meta do dia, conquista) ficam salvos em `users/{uid}/notifications` por **30 dias**, com a marcação de lido. Contrato e regras em `firestore-rules.md` §7.
    - Efeito nos documentos legais (sessão de dados e legal): incluir a categoria no inventário de dados e na Política, com finalidade, base legal, prazo de 30 dias e exclusão junto com a conta. Hoje a Política só descreve notificações locais.

## C. Lacunas no design (sessão de prototipação)

1. **Tela "Excluir conta"** no app, exigida pelo Google Play, que também pede um link web para solicitar a exclusão. Item aprovado no Perfil (etapa 11); falta a tela e o link web.
2. ~~Aceite dos Termos no primeiro login com Google.~~ Resolvido: tela "03b Primeiro acesso com Google" (sessão de regras de segurança, etapa 1).
3. ~~Confirmação de idade (16+) no Cadastro e no primeiro login social.~~ Resolvido: campo de data de nascimento no Cadastro e no 03b.
4. Verificação de e-mail: Q1 exige e-mail verificado; contas Google já chegam verificadas. Confirmar no protótipo que a tela 05 só aparece para e-mail/senha.
5. **Links para os Termos e a Política** acessíveis no app: aprovados no Perfil (etapa 11), falta desenhar.

## D. Itens para o advogado

1. **Adolescentes de 16–17 anos:**
   - assistência dos pais para aceitar os Termos (Código Civil, art. 4º);
   - LGPD art. 14 (melhor interesse);
   - exigências da Lei nº 15.211/2025 (ECA Digital), inclusive se a data de nascimento informada no cadastro basta como verificação de idade ou se é preciso outro mecanismo;
   - base legal para tratar a data de nascimento (Política 5).
2. **Encarregado (DPO):** se uma pessoa física se enquadra como agente de pequeno porte (Res. CD/ANPD nº 2/2022) e se dados de adolescentes tornam o tratamento de "alto risco", o que obrigaria a nomear encarregado.
3. **Registros de acesso (Marco Civil, art. 15):** se a guarda de IP + data/hora por 6 meses se aplica a controlador pessoa física.
4. **Transferência internacional:** mecanismo adequado para os serviços do Firebase fora do Brasil (Res. CD/ANPD nº 19/2024) e a redação da Política 7.
5. **Limitação de responsabilidade** (Termos 13) à luz do CDC, inclusive para serviço gratuito.
6. **Base legal** de cada finalidade (Política 5), especialmente legítimo interesse para segurança e Crashlytics. Avaliar a necessidade de um teste de balanceamento (LIA).
7. **Prazo de guarda do registro de aceite** após a exclusão da conta.
8. **Marca "Nexo":** busca de anterioridade e registro no INPI.
9. **Branding do botão do Google:** conferir as diretrizes de marca do Google antes de publicar (fonte Manrope × Roboto recomendada pelo Google).

## E. Marca

1. **Logo do Nexo: definida em 21/10/2026.** Símbolo "x como ponto de encontro" (um traço reto passa sob um traço curvo), usado com o nome "Nexo" em Manrope 700. Fonte: `pen.dev/nexo.brand.pen`. Pacote (versões claro/escuro, monocromática, ícones iOS e Android adaptativo, favicons) em `D:\Dev\Nexo\app\assets\brand\` (README com regras de uso; movido de `D:\Dev\Nexo\brand\` em 21/10/2026). **Aplicada (21/10/2026):** lib com os componentes Brand/Logo/* (Symbol, Lockup, Wordmark, Symbol/96, Lockup/32); app com 13 instâncias no lugar dos fallbacks de texto (Splash, Login, tutorial). **Ainda pendente:** busca de anterioridade e registro no INPI (D8) antes de publicar.
