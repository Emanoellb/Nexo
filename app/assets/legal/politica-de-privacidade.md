<!-- NOTA INTERNA: rascunho v0.3, ainda sem revisão jurídica (Etapa 5). Não publicar fora do app antes do advogado. -->
<!-- NOTA INTERNA: os comentários HTML não aparecem no app (legal_markdown.dart). Escreva cada nota numa linha própria, começando por "<!--"; comentário no meio da frase aparece para o usuário. -->
<!-- NOTA INTERNA: a versão técnica em legalDocuments/current (privacy-2026-11-01) é só para o cadastro funcionar nos testes. Os pontos para o advogado estão em app/docs/legal/pendencias.md, seção "Notas tiradas do texto público". -->
<!-- NOTA INTERNA: formato aceito pelo leitor do app: #, ##, ###, parágrafos, listas, negrito e citações. Sem tabelas, links, crases ou imagens. -->

# Política de Privacidade do Nexo

**Versão:** 0.3 · **Vigência:** a definir

Esta Política explica quais dados pessoais o aplicativo Nexo coleta, por que coleta, com quem compartilha, por quanto tempo guarda e como você pode exercer seus direitos. Ela segue a Lei Geral de Proteção de Dados Pessoais (Lei nº 13.709/2018, "LGPD").

## 1. Quem é responsável pelos seus dados

O controlador dos seus dados pessoais é Emanoel Barbosa, pessoa física responsável pelo Nexo.

- **Contato para assuntos de privacidade:** emanoelbarbosa.dev@gmail.com
- **Encarregado pelo tratamento de dados (DPO):** emanoelbarbosa.dev@gmail.com

<!-- ADVOGADO (P1): confirmar se a pessoa física precisa nomear encarregado (Res. CD/ANPD nº 2/2022) e se dados de adolescentes tornam o tratamento de alto risco. -->

## 2. A quem esta Política se aplica

Ela vale para quem usa o aplicativo Nexo para Android. O Nexo é destinado a pessoas com **16 anos ou mais**. Veja a seção 12 sobre usuários entre 16 e 18 anos.

## 3. Quais dados coletamos

### 3.1 Dados da sua conta

- **E-mail e senha**, se você criar a conta com e-mail. A senha é guardada pelo serviço de autenticação de forma protegida, e nós nunca temos acesso a ela em texto.
- **Dados do login com Google**, se você entrar com a sua conta Google: nome, e-mail e identificador da conta. Não guardamos a sua foto de perfil.
- **Data de nascimento**, pedida no cadastro para conferir a idade mínima de 16 anos. Depois do cadastro, ela não pode ser alterada no app; para corrigir, fale com a gente pelo contato da seção 1.
- **Status de verificação do e-mail**, datas de criação e de último acesso.
- **Registro do aceite** destes documentos: as versões dos Termos e da Política que você aceitou e a data e hora do aceite.
- **Pedido de exclusão da conta**, com data e hora, enquanto a exclusão está em andamento.

### 3.2 Dados do seu perfil e das preferências guardadas na sua conta

- Nome ou como você quer ser chamado.
- Fuso horário do aparelho, usado para fechar os seus dias e agendar os avisos no horário certo.
- Preferências: tutorial visto, plano principal, limite de tarefas por dia para o dia "sobrecarregado" e o aviso da manhã (ligado ou não e o horário).
- Seus pontos acumulados.

### 3.3 Conteúdo que você cria

- **Objetivos:** nome, com descrição e prazo opcionais.
- **Planos de ação:** nome, datas de início e fim, frequência, meta diária, status (ativo, pausado, concluído, encerrado ou arquivado), pausas, data de encerramento antecipado, objetivo ligado, horário do plano, aviso antes do horário e histórico de alterações da meta e da frequência.
- **Tópicos dos planos:** nome e, se você quiser, a disciplina a que pertencem.
- **Sessões de foco e registros manuais de tempo:** horário de início e fim, duração (já sem as pausas), origem (cronômetro ou registro manual), até 3 tópicos e uma nota opcional.
- **Dias dos planos:** minutos realizados em cada dia e, quando for o caso, a data e hora em que você finalizou o dia.
- **Tarefas:** título, disciplina, prazo, prioridade, situação da entrega, até 3 avisos antes do prazo e se foi concluída (com a data).
- **Disciplinas:** nome e ícone.
- **Conquistas:** quais medalhas você ganhou e quando.

Vários desses campos são **texto livre** (nomes, descrições, tópicos, notas, títulos). **Pedimos que você não escreva neles dados sensíveis**, como informações de saúde, religião, opinião política ou vida sexual. Usamos esse conteúdo só para mostrá-lo de volta a você e calcular o seu progresso.

### 3.4 Histórico de avisos

Os avisos importantes (entrega próxima, tarefa atrasada, meta do dia e conquista) ficam guardados na sua conta por **30 dias**, para você revê-los no painel de avisos do app, com a marcação de lido. Depois disso, são apagados automaticamente.

<!-- PENDÊNCIA: a apagada automática depende do TTL do Firestore (firebase-setup.md A13), que só será criado depois do primeiro aviso gravado. Criar antes de publicar. -->

### 3.5 Dados que o Nexo calcula

A partir do que você registra, o app calcula:

- tempo realizado, saldo e divisão do tempo entre os tópicos;
- meta e status de cada dia do plano;
- nível, sequência de dias e relatórios;
- contagem de entregas por disciplina, tarefas atrasadas e carga de cada dia no calendário.

Esses cálculos seguem regras fixas e iguais para todos os usuários, descritas no próprio app (por exemplo: 1 ponto por tarefa concluída; 7, 5, 3 ou 0 pontos por dia de plano, conforme o resultado; um nível a cada 20 pontos). **Não usamos esses dados para tomar decisões que afetem seus direitos**, nem para criar rankings ou comparar você com outras pessoas.

### 3.6 Dados técnicos

- **Relatórios de falha (Firebase Crashlytics):** quando o app trava, registramos o erro técnico, o modelo do aparelho, a versão do sistema e do app, o estado do aparelho naquele momento (como memória livre e orientação da tela) e um identificador de instalação. Esses relatórios não incluem seu nome, seu e-mail nem o que você escreve no app, e servem só para corrigir falhas.

<!-- ADVOGADO (P3): guarda de registros de acesso (endereço IP, data e hora) do Marco Civil da Internet, art. 15. Se valer para pessoa física, voltam um item aqui, uma finalidade na seção 5 (obrigação legal, art. 7º, II) e um prazo de 6 meses na seção 9. -->

### 3.7 Dados que ficam só no seu aparelho

- **Uso sem internet:** parte dos seus dados fica guardada no próprio aparelho e é sincronizada quando a conexão volta.
- **Sessão de foco em andamento:** o plano, o horário de início, as pausas e os tópicos escolhidos ficam só no aparelho. Quando você encerra, a sessão vai para a sua conta, já sem as pausas.
- **Preferências do aparelho:** tema (sistema, claro ou escuro), "Ligar o Não perturbe ao focar", "Reduzir transparência" e outras escolhas de exibição. Elas **nunca são enviadas aos nossos servidores** e voltam ao padrão se você reinstalar o app.
- **Agendamento dos avisos:** os avisos são programados no próprio aparelho (veja a seção 11).

### 3.8 Mensagens ao suporte

Se você escreve para o suporte, inclusive pelo "Pedir cópia dos dados" do Perfil, guardamos o endereço de quem enviou, o assunto, o conteúdo e a data das mensagens, além da cópia dos dados que enviarmos a você.

## 4. Dados que não coletamos

- Localização.
- Contatos, fotos, câmera ou microfone.
- O conteúdo das notificações de outros apps.
- Agendas externas, como o Google Agenda.
- Identificador de publicidade.
- Dados de uso para fins de análise de comportamento (não usamos ferramentas de analytics no MVP).

O Nexo **não exibe anúncios** e **não vende dados pessoais**.

## 5. Para que usamos os dados e com qual base legal

As bases legais são as do art. 7º da LGPD.

- **Criar, autenticar e manter sua conta:** conta e perfil · execução de contrato.
- **Conferir a idade mínima de 16 anos:** data de nascimento · execução de contrato.
- **Oferecer as funcionalidades** (objetivos, planos, sessões, tarefas, calendário, relatórios, pontos e conquistas): conteúdo que você cria e dados calculados · execução de contrato.
- **Agendar os avisos que você configurou e mostrar o histórico de avisos dos últimos 30 dias:** horários e preferências de aviso, prazos das tarefas e histórico de avisos · execução de contrato.
- **Enviar e-mails do sistema** (verificação e redefinição de senha): e-mail · execução de contrato.
- **Excluir sua conta quando você pede:** pedido de exclusão · execução de contrato.
- **Proteger a conta contra acesso indevido** (por exemplo, bloqueio após muitas tentativas): dados de login · legítimo interesse.
- **Corrigir falhas do app:** relatórios de falha · legítimo interesse.
- **Guardar a prova do seu aceite destes documentos:** registro de aceite · exercício regular de direitos.
- **Responder ao suporte e atender seus pedidos sobre seus dados:** mensagens ao suporte e cópia enviada · cumprimento de obrigação legal e execução de contrato.

<!-- ADVOGADO (P6): validar a base legal de cada finalidade, em especial a da data de nascimento e o legítimo interesse (segurança e Crashlytics), com teste de balanceamento se preciso. -->

Não enviamos comunicações de marketing. Se isso mudar, pediremos o seu consentimento separadamente, e você poderá recusar sem perder acesso ao app.

## 6. Com quem compartilhamos

- **Google (Firebase)**, que opera a infraestrutura do Nexo: autenticação, banco de dados e relatórios de falha. O Google trata os dados por nossa conta, como **operador**, conforme os termos de processamento de dados do Firebase.
- **Google como provedor de login**, se você escolher entrar com a sua conta Google. Nesse caso, o Google também trata dados conforme a política de privacidade própria.
- **Google (Gmail)**, que hospeda a caixa de e-mail do suporte. As mensagens que você envia ao suporte, as respostas e a cópia dos dados enviada ficam guardadas nesse serviço, que as trata por nossa conta, como **operador**.
- **Autoridades públicas**, quando houver obrigação legal ou ordem judicial.

<!-- ADVOGADO (P9): o suporte usa uma conta Gmail pessoal, que não tem termos de processamento de dados como o Firebase. Confirmar se o Google pode ser descrito como operador nesse caso ou se é preciso uma conta com esses termos (ex.: Google Workspace). -->


Não compartilhamos dados com anunciantes nem com outras empresas para fins comerciais.

## 7. Transferência internacional de dados

O banco de dados principal do Nexo fica em São Paulo, no Brasil. Alguns serviços do Firebase, como a autenticação e os relatórios de falha, processam dados em servidores fora do Brasil, principalmente nos Estados Unidos. A transferência segue os mecanismos previstos na LGPD.

<!-- ADVOGADO (P4): definir o mecanismo da transferência (Resolução CD/ANPD nº 19/2024, por exemplo cláusulas-padrão contratuais) e ajustar a última frase. Região do banco: southamerica-east1. -->

## 8. Segurança

Usamos as proteções da plataforma Firebase: comunicação criptografada, regras de acesso que permitem que só você leia e altere os seus dados, e senhas que nunca ficam guardadas em texto. Nenhum sistema é totalmente imune a incidentes. Se houver um incidente que possa causar risco ou dano relevante, avisaremos você e a Autoridade Nacional de Proteção de Dados (ANPD), como exige a lei.

## 9. Por quanto tempo guardamos

- **Enquanto sua conta existir**, guardamos os dados necessários para o app funcionar.
- **Itens que você exclui** (planos, sessões, tarefas etc.) saem da sua conta na hora. Ao excluir um plano, apagamos junto as sessões, os dias e os tópicos dele.
- **Histórico de avisos:** 30 dias. A remoção automática pode levar até cerca de um dia a mais; nesse intervalo, o app já não mostra o aviso vencido.
- **Ao excluir a conta**, apagamos seus dados pessoais. Cópias de segurança são eliminadas em até 7 dias.
- **Relatórios de falha** são mantidos por até 90 dias.
- **Mensagens ao suporte** e a cópia dos dados enviada são mantidas por até 12 meses depois de encerrado o atendimento, para comprovar que o pedido foi atendido.
- **O registro do seu aceite** pode ser mantido após a exclusão da conta pelo prazo necessário à defesa de direitos.

<!-- ADVOGADO (P7): definir o prazo de guarda do registro de aceite depois da exclusão da conta. -->

## 10. Seus direitos

Pela LGPD (art. 18), você pode:

1. confirmar se tratamos seus dados e acessá-los;
2. corrigir dados incompletos, inexatos ou desatualizados;
3. pedir anonimização, bloqueio ou eliminação de dados desnecessários ou tratados em desacordo com a lei;
4. pedir a portabilidade dos seus dados;
5. pedir a eliminação dos dados tratados com base no seu consentimento;
6. saber com quem compartilhamos seus dados;
7. ser informado sobre a possibilidade de não dar consentimento e as consequências disso;
8. revogar o consentimento, quando ele for a base legal;
9. se opor a tratamento feito com base em legítimo interesse, se considerar que ele não cumpre a lei.

**Como exercer:**

- A maior parte dos dados você mesmo pode ver, editar e excluir no app.
- **Excluir a conta:** no **Perfil** do app (por segurança, pedimos que você entre de novo antes) ou pelo e-mail emanoelbarbosa.dev@gmail.com. Se o app fechar no meio, a exclusão continua no próximo login.
- **Cópia dos seus dados (portabilidade) e demais pedidos:** pelo **Perfil** do app (Pedir cópia dos dados) ou pelo e-mail emanoelbarbosa.dev@gmail.com. Respondemos em até 15 dias. A cópia vai em formato eletrônico legível (planilha ou JSON). Por segurança, enviamos a cópia só para o e-mail cadastrado na sua conta (para quem entra com Google, o e-mail da conta Google). Se o pedido chegar de outro endereço, respondemos pedindo que você o repita a partir do e-mail da conta. Assim, ninguém recebe dados que não são seus.

<!-- PENDÊNCIA (Etapa 5): trocar o e-mail da exclusão pelo link da página pública de exclusão exigida pelo Google Play. -->

Você também pode apresentar reclamação à ANPD (www.gov.br/anpd).

## 11. Avisos e permissões do aparelho

**Avisos.** O Nexo mostra notificações para os avisos que você mantém ligados:

- aviso antes do horário do plano;
- aviso da manhã, com o resumo do dia;
- aviso à noite (21h) se a meta do dia não estiver completa;
- aviso 7 dias antes do fim do plano;
- avisos antes do prazo de uma tarefa (até 3 por tarefa).

O limite é de um aviso por plano por dia. Os avisos são agendados no próprio aparelho: os horários que você escolhe ficam salvos na sua conta, mas nenhum identificador de notificação do aparelho é enviado aos nossos servidores. Você pode desligá-los no app ou nas configurações do aparelho.

<!-- PENDÊNCIA: o app ainda não agenda os avisos (Etapa 5). O texto descreve o produto como vai ser publicado (decisão do usuário, 10/11). -->

**Permissões**

<!-- PENDÊNCIA: CONFIRMAR A LISTA FINAL NO APP ANTES DE PUBLICAR. A Etapa 5 traz a permissão de reagendar os avisos depois que o aparelho reinicia. -->

Permissões que o app pede a você:

- **Notificações:** pedida na sua primeira sessão de foco (Android 13 ou mais recente). Serve para a notificação fixa do cronômetro, que mostra a sessão em andamento, e para os avisos. As notificações são criadas no próprio aparelho, e nenhum dado é enviado por elas.
- **Acesso ao "Não perturbe" (opcional):** só se você ligar a opção "Ligar o Não perturbe ao focar". Você dá esse acesso uma vez, nas configurações do sistema. O app liga o modo durante a sessão de foco e devolve o estado anterior quando você encerra a sessão (ou na próxima vez que abrir o app). Não lemos suas notificações nem seus contatos.

Permissões automáticas, que o Android concede sem perguntar:

- **Internet:** para entrar na sua conta, guardar seus dados e enviar relatórios de falha.
- **Estado da conexão:** para avisar quando você está sem internet. Não coletamos dados da sua rede.
- **Biometria e impressão digital:** vêm junto com a biblioteca de login do Google. **O Nexo não usa nem lê sua biometria**, e nenhuma tela do app pede isso.
- **Serviços do Google:** vem junto com a proteção contra abuso do login (reCAPTCHA), do Firebase.

<!-- PENDÊNCIA: confirmar se a proteção reCAPTCHA está ativa no console e quais sinais do aparelho ela envia ao Google; ajustar o item acima. -->

O Nexo não usa alarmes exatos nem serviços que fiquem rodando em segundo plano.

## 12. Usuários entre 16 e 18 anos

O Nexo não é destinado a menores de 16 anos. O cadastro confere a idade pela data de nascimento. Se soubermos que uma conta pertence a alguém com menos de 16 anos, ela será excluída. Usuários entre 16 e 18 anos têm seus dados tratados no seu melhor interesse, sem perfil comercial nem publicidade. Pais ou responsáveis podem entrar em contato pelo e-mail emanoelbarbosa.dev@gmail.com.

<!-- ADVOGADO (P5): ciência ou assistência dos pais ou responsáveis e exigências da Lei nº 15.211/2025 (ECA Digital), inclusive se a data de nascimento basta como verificação de idade. -->

## 13. Alterações desta Política

Podemos atualizar esta Política. Se a mudança for relevante, avisaremos no app e, quando necessário, pediremos um novo aceite. A versão e a data de vigência ficam no topo deste documento.

## 14. Contato

Emanoel Barbosa · emanoelbarbosa.dev@gmail.com
