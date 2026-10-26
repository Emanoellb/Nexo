> **RASCUNHO — NÃO PUBLICAR.** Este texto foi redigido a partir do inventário de dados do MVP (`inventario-dados-mvp.md`) e **precisa de revisão jurídica antes de qualquer publicação**. Os trechos entre colchetes (`[ASSIM]`) são informações que ainda não existem ou decisões pendentes. A lista completa está em `pendencias.md`.

# Política de Privacidade do Nexo

**Versão:** 0.2 (rascunho) · **Vigência a partir de:** 01/11/2026

Esta Política explica quais dados pessoais o aplicativo Nexo coleta, por que coleta, com quem compartilha, por quanto tempo guarda e como você pode exercer seus direitos. Ela segue a Lei Geral de Proteção de Dados Pessoais (Lei nº 13.709/2018, "LGPD").

## 1. Quem é responsável pelos seus dados

O controlador dos seus dados pessoais é Emanoel Lima Barbosa, pessoa física responsável pelo Nexo.

- **Contato para assuntos de privacidade:** emanoelbarbosa.dev@gmail.com
- **Encarregado pelo tratamento de dados (DPO):** emanoelbarbosa.dev@gmail.com `[VALIDAR COM ADVOGADO: obrigatoriedade de nomear encarregado]`

## 2. A quem esta Política se aplica

Ela vale para quem usa o aplicativo Nexo para Android. O Nexo é destinado a pessoas com **16 anos ou mais**. Veja a seção 12 sobre usuários entre 16 e 18 anos.

## 3. Quais dados coletamos

### 3.1 Dados da sua conta

- **E-mail e senha**, se você criar a conta com e-mail. A senha é guardada pelo serviço de autenticação de forma protegida, e nós nunca temos acesso a ela em texto.
- **Dados do login com Google**, se você entrar com a sua conta Google: nome, e-mail e identificador da conta. Não guardamos a sua foto de perfil.
- **Data de nascimento**, pedida no cadastro para conferir a idade mínima de 16 anos. Depois do cadastro, ela não pode ser alterada no app; para corrigir, fale com a gente pelo contato da seção 1.
- **Status de verificação do e-mail**, datas de criação e de último acesso.
- **Registro do aceite** destes documentos: as versões dos Termos e da Política que você aceitou e a data e hora do aceite.

### 3.2 Dados do seu perfil e das suas preferências

- Nome ou como você quer ser chamado.
- Fuso horário do aparelho, usado para fechar os seus dias no horário certo.
- Preferências do app: tutorial visto, horários de lembrete, aviso noturno, horário de silêncio e limite de "dia sobrecarregado".

### 3.3 Conteúdo que você cria

- **Objetivos:** nome, descrição e prazo opcionais e os planos agrupados neles.
- **Planos de ação:** nome, datas de início e fim, frequência, meta diária, status (ativo, pausado, concluído, encerrado ou arquivado), pausas, plano principal, lembrete e histórico de alterações.
- **Sessões de foco e registros manuais de horas:** horário de início e fim, duração, pausas, origem (cronômetro ou registro manual), tópico e nota opcionais.
- **Tarefas:** título, disciplina, prazo, prioridade, status de entrega, notas e se foi concluída (com a data).
- **Disciplinas:** nome e ícone.

Vários desses campos são **texto livre** (nomes, descrições, tópicos, notas, títulos). **Pedimos que você não escreva neles dados sensíveis**, como informações de saúde, religião, opinião política ou vida sexual. Usamos esse conteúdo só para mostrá-lo de volta a você e calcular o seu progresso.

### 3.4 Dados que o Nexo calcula

A partir do que você registra, o app calcula:

- horas realizadas e saldo de horas;
- status de cada dia do plano;
- pontos, nível, sequência de dias e conquistas;
- relatórios parciais e finais;
- contagem de entregas por disciplina e carga de cada dia no calendário.

Esses cálculos seguem regras fixas e iguais para todos os usuários, descritas no próprio app (por exemplo: 1 ponto por tarefa concluída; 5, 3, 7 ou 0 pontos por dia de plano, conforme o resultado). **Não usamos esses dados para tomar decisões que afetem seus direitos**, nem para criar rankings ou comparar você com outras pessoas.

### 3.5 Dados técnicos

- **Relatórios de falha (Firebase Crashlytics):** quando o app trava, registramos o erro técnico, o modelo do aparelho, a versão do sistema e do app, o estado do aparelho naquele momento (como memória livre e orientação da tela) e um identificador de instalação. Esses relatórios servem só para corrigir falhas.
- `[VALIDAR COM ADVOGADO: guarda de registros de acesso (endereço IP, data e hora) — Marco Civil da Internet, art. 15]`.

### 3.6 Dados guardados no seu aparelho

Para você usar o app sem internet, parte dos seus dados fica guardada no próprio aparelho e é sincronizada quando a conexão volta. O cronômetro de foco grava o horário de início da sessão, e por isso continua contando mesmo com o app fechado. Os lembretes também são agendados no próprio aparelho (veja a seção 11).

## 4. Dados que não coletamos

- Localização.
- Contatos, fotos, câmera ou microfone.
- Agendas externas, como o Google Agenda.
- Identificador de publicidade.
- Dados de uso para fins de análise de comportamento (não usamos ferramentas de analytics no MVP).

O Nexo **não exibe anúncios** e **não vende dados pessoais**.

## 5. Para que usamos os dados e com qual base legal

| Finalidade | Dados | Base legal (LGPD, art. 7º) |
|---|---|---|
| Criar, autenticar e manter sua conta | Conta, perfil | Execução de contrato (V) |
| Conferir a idade mínima de 16 anos | Data de nascimento | Execução de contrato (V) `[VALIDAR COM ADVOGADO: base legal]` |
| Oferecer as funcionalidades (planos, sessões, tarefas, calendário, relatórios, pontos) | Conteúdo que você cria, dados calculados | Execução de contrato (V) |
| Agendar os lembretes que você configurou e enviar e-mails do sistema (verificação, redefinição de senha) | E-mail, preferências, horários de lembrete | Execução de contrato (V) |
| Proteger a conta contra acesso indevido (ex.: bloqueio após muitas tentativas) | Dados de login | Legítimo interesse (IX) |
| Corrigir falhas do app | Relatórios de falha | Legítimo interesse (IX) |
| Guardar a prova do seu aceite destes documentos | Registro de aceite | Exercício regular de direitos (VI) |
| `[SE APLICÁVEL]` Guardar registros de acesso | IP, data e hora | Cumprimento de obrigação legal (II) |

Não enviamos comunicações de marketing. Se isso mudar, pediremos o seu consentimento separadamente, e você poderá recusar sem perder acesso ao app.

## 6. Com quem compartilhamos

- **Google (Firebase)**, que opera a infraestrutura do Nexo: autenticação, banco de dados, funções na nuvem e relatórios de falha. O Google trata os dados por nossa conta, como **operador**, conforme os termos de processamento de dados do Firebase.
- **Google como provedor de login**, se você escolher entrar com a sua conta Google. Nesse caso, o Google também trata dados conforme a política de privacidade própria.
- **Autoridades públicas**, quando houver obrigação legal ou ordem judicial.

Não compartilhamos dados com anunciantes nem com outras empresas para fins comerciais.

## 7. Transferência internacional de dados

O banco de dados principal do Nexo fica em São Paulo, no Brasil (região `southamerica-east1` do Google Cloud). Alguns serviços do Firebase, como a autenticação e os relatórios de falha, processam dados em servidores fora do Brasil, principalmente nos Estados Unidos. A transferência internacional é feita `[VALIDAR COM ADVOGADO: mecanismo da Resolução CD/ANPD nº 19/2024, ex.: cláusulas-padrão contratuais]`.

## 8. Segurança

Usamos as proteções da plataforma Firebase: comunicação criptografada, regras de acesso que permitem que só você leia e altere os seus dados, e senhas que nunca ficam guardadas em texto. Nenhum sistema é totalmente imune a incidentes. Se houver um incidente que possa causar risco ou dano relevante, avisaremos você e a Autoridade Nacional de Proteção de Dados (ANPD), como exige a lei.

## 9. Por quanto tempo guardamos

- **Enquanto sua conta existir**, guardamos os dados necessários para o app funcionar.
- **Itens que você exclui** (planos, sessões, tarefas etc.) saem da sua conta na hora.
- **Ao excluir a conta**, apagamos seus dados pessoais. Cópias de segurança são eliminadas em até 7 dias.
- **Relatórios de falha** são mantidos por até 90 dias.
- **O registro do seu aceite** pode ser mantido após a exclusão da conta pelo prazo necessário à defesa de direitos `[VALIDAR COM ADVOGADO]`.
- `[SE APLICÁVEL]` **Registros de acesso** são mantidos por 6 meses, conforme o Marco Civil da Internet.

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
- **Excluir a conta:** no **Perfil** do app ou pelo link `[URL DA PÁGINA DE EXCLUSÃO]`.
- **Cópia dos seus dados (portabilidade) e demais pedidos:** pelo **Perfil** do app ou pelo e-mail emanoelbarbosa.dev@gmail.com. Respondemos em até 15 dias.

Você também pode apresentar reclamação à ANPD (www.gov.br/anpd).

## 11. Notificações

O Nexo mostra notificações só para os lembretes que você ativa:

- lembrete diário do plano;
- aviso à noite se a meta do dia não estiver completa;
- aviso 7 dias antes do fim do plano;
- aviso de tarefa com entrega próxima.

O limite é de uma notificação por plano por dia. Os lembretes são agendados no próprio aparelho: os horários que você escolhe ficam salvos na sua conta, mas nenhum identificador de notificação do aparelho é enviado aos nossos servidores. Você pode desativá-los no app ou nas configurações do aparelho.

## 12. Usuários entre 16 e 18 anos

O Nexo não é destinado a menores de 16 anos. O cadastro confere a idade pela data de nascimento. Se soubermos que uma conta pertence a alguém com menos de 16 anos, ela será excluída. Usuários entre 16 e 18 anos têm seus dados tratados no seu melhor interesse, sem perfil comercial nem publicidade, e `[VALIDAR COM ADVOGADO: ciência/assistência dos pais ou responsáveis e exigências da Lei nº 15.211/2025 (ECA Digital)]`. Pais ou responsáveis podem entrar em contato pelo e-mail emanoelbarbosa.dev@gmail.com.

## 13. Alterações desta Política

Podemos atualizar esta Política. Se a mudança for relevante, avisaremos no app e, quando necessário, pediremos um novo aceite. A versão e a data de vigência ficam no topo deste documento.

## 14. Contato

Emanoel Lima Barbosa · emanoelbarbosa.dev@gmail.com
