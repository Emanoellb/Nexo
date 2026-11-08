# Pendências dos documentos legais do Nexo (MVP)

Data: 2026-10-20 · atualizado em 2026-10-22 e **2026-11-07**. Documentos: `termos-de-uso.md` e `politica-de-privacidade.md` (rascunhos **v0.3**). Base: `inventario-dados-mvp.md` (v0.3).

## Mudanças da v0.3 (07/11/2026)

Pedido do usuário pela sessão principal ("pode seguir com o legal"), depois das regras do Firestore v0.9. Detalhes no inventário, tabela "Atualizações de 07/11" (V1–V11).

1. **Política:**
   - campos da v0.9: até 3 avisos por tarefa, horário do plano e aviso antes do horário, aviso da manhã, até 3 tópicos por sessão;
   - tópicos do plano, pontos, plano principal, dias (minutos e finalização), conquistas e pedido de exclusão;
   - **histórico de avisos por 30 dias** (B13);
   - preferências que ficam **só no aparelho**;
   - nova seção 11, **Avisos e permissões do aparelho**;
   - saíram: notas da tarefa, pausas dentro da sessão e "funções na nuvem" (não há Cloud Functions no MVP).
2. **Termos:**
   - descrição do produto **neutra** (qualquer objetivo, não só estudo);
   - avisos, histórico e permissões opcionais;
   - preferências locais voltam ao padrão ao reinstalar.
3. **Vigência:** a de 01/11/2026 **passou sem publicação**. Os dois documentos agora dizem `[DATA DE VIGÊNCIA: definir na publicação]` e trazem uma nota interna sobre as versões técnicas em `legalDocuments/current`.
4. **Fechados:** o risco da etapa 10 (item 12 da v0.2), porque as notificações locais foram decididas em 24/10; e o B13, incorporado (ver item 13 da seção B).

### Decisões que ficaram para o usuário (v0.3)

| # | Decisão | Recomendação |
|---|---|---|
| L1 | **IDs das versões** em `legalDocuments/current`. Hoje: `terms-2026-11-01` e `privacy-2026-11-01`, apontando para textos que mudaram | Manter os IDs atuais enquanto tudo for rascunho e não houver usuários reais. Na publicação, depois do advogado, criar IDs com a data de vigência (ex.: `terms-AAAA-MM-DD`). Trocar o `current` agora obrigaria as contas de teste a aceitar de novo, sem ganho jurídico |
| L2 | **Trocar `legalDocuments/current`** no console | Só com OK explícito do usuário (ação no console, banco único F2) |
| L3 | **Data de vigência** | Definir só depois da revisão jurídica |

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
12. **Lembretes descritos como notificações locais** (sem token FCM no servidor), por decisão do usuário, antes da etapa 10 fechar. ~~Se a etapa 10 voltar para FCM, revisar a Política.~~ **Fechado:** notificações locais decididas em 24/10/2026.
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
| Data de vigência | Topo dos dois documentos | **Aberto (v0.3).** 01/11/2026 passou sem publicação; definir depois do advogado (L3) |
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
8. **Ambientes:** **sem efeito nos documentos.** **Um projeto Firebase só, `nexo-app-gestao-f97bb`** (F2; 21/10/2026, **confirmado em 04/11/2026**). A separação dev × prod decidida em 26/10/2026 foi cancelada antes de qualquer mudança no console (`firebase-setup.md` §14). Risco aceito: testes e usuários reais dividem banco, cotas e templates; rever antes do lançamento público. Nada muda nos documentos legais.
9. **Plano do Firebase:** **Blaze, contratado pelo usuário em 21/10/2026** (F4). Alerta de orçamento **criado em 04/11/2026**: R$ 20/mês, alertas em 50%, 90% e 100%. Ele só avisa; não limita o gasto. A conta usa créditos de teste que vencem por volta de 19/01/2027: antes disso, o usuário decide entre ativar a conta paga e voltar para o Spark (`firebase-setup.md` §2). Fecha o R6 da spec de redefinição de senha.
10. **Plataforma do MVP:** **decidido em 21/10/2026: só Android** (F6).
11. **Apple:** **decidido em 21/10/2026: nada da Apple no MVP** (F7). Isso exclui Sign in with Apple, Apple Developer Program e iOS. O login do MVP é e-mail/senha + Google.
    - Efeito nos documentos legais: **aplicado na v0.2** (Termos, Política e inventário sem Apple).
    - Efeito no design: os botões e fluxos de login Apple saem do MVP (sessão de prototipação).
    - Efeito na spec de redefinição de senha: ela ainda cita a Apple (Email Sources, testes). Revisar com a sessão nexo-reset-senha.
12. **Projeto Firebase:** criado pelo usuário. Nome `nexo-app-gestao`, **Project ID `nexo-app-gestao-f97bb`** (permanente). Esse ID aparece no remetente dos e-mails enquanto não houver domínio próprio.
13. **Histórico de notificações:** **decidido em 04/11/2026**, entra no bloco de integração. Os avisos (entrega próxima, tarefa atrasada, meta do dia, conquista) ficam salvos em `users/{uid}/notifications` por **30 dias**, com a marcação de lido. Contrato e regras em `firestore-rules.md` §7.
    - Efeito nos documentos legais: **incorporado na v0.3 (07/11/2026)**: inventário seção 11, Política 3.4, 5 e 9, Termos 8.
    - **Atenção:** o contrato de `notifications` e as regras ainda não foram publicados, e a política de TTL só será criada depois do primeiro aviso gravado (`firebase-setup.md` A13). Sem o TTL, os avisos não somem aos 30 dias, e a Política 9 não é cumprida. Criar o TTL antes de publicar a Política.

14. **Permissões do Android (Etapa 3c):** acesso ao "Não perturbe" (opcional), notificação fixa do cronômetro (provável serviço em primeiro plano), notificações locais, estado da conexão e vibração. Descritas na Política 11 com o marcador `[CONFIRMAR A LISTA FINAL NO APP]`.
    - Depois da 3c: conferir o `AndroidManifest.xml` final, inclusive se o pacote de notificações pede alarmes exatos, e ajustar a Política 11.
    - A mesma lista alimenta o formulário "Segurança dos dados" do Google Play.
15. **Preferências só no aparelho** (07/11/2026): tema, "Não perturbe ao focar", "Reduzir transparência" e silêncio dos avisos. Incorporado na Política 3.7 e no inventário (V4).
16. **Contato:** só o e-mail. O telefone, que hoje é fictício, **não** entra nos documentos.

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
