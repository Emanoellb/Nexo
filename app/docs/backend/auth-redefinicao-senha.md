# Nexo · Redefinição de senha ("Esqueci minha senha") no Firebase

Status: **v1.0, aprovada pelo usuário em 21/10/2026** (decisões R1, R2, R3 e R7). R4, R5 e R6 continuam abertas para a sessão de infra · Sessão: nexo-reset-senha
Escopo: especificação funcional. Nenhum código de produção e nenhuma alteração em projeto Firebase real.
Fontes do produto: tela 04 do `nexo.app.pen` (estados Default e Link enviado), `docs/legal/inventario-dados-mvp.md` (seções 1, 12 e 13), `docs/legal/pendencias.md` (B5).

Legenda: **[C]** confirmado na documentação oficial (URL na seção 10) · **[NC]** não confirmado, precisa de teste no projeto · **[D]** decisão proposta, depende de aprovação.

---

## 1. Resumo

- O app chama `sendPasswordResetEmail`. O Firebase Auth manda o e-mail com um link de uso único [C] que expira [C]. O prazo exato da expiração é [NC].
- **Decidido (R1): no MVP a nova senha é criada na página padrão do Firebase**, e não numa tela do app. Isso evita deep link, App Links e Universal Links no MVP e continua funcionando quando o e-mail é aberto no computador. A tela no app fica para depois do MVP.
- A **email enumeration protection** já vem ligada em projetos criados a partir de 15/09/2023 [C]. Com ela, a chamada não revela se a conta existe, e a mensagem neutra da tela 04 já está alinhada.
- **Dois ajustes no e-mail, aprovados (R2 e R3):**
  - Sai "vale por 1 hora", porque a documentação não confirma o prazo.
  - "Olá, %DISPLAY_NAME%" vira "Olá!", porque não está confirmado o que acontece quando o nome vem vazio.
- **Cota:** no plano Spark o projeto inteiro envia só **150 e-mails de redefinição por dia** [C]. No Blaze são 10.000 [C]. Isso é decisão de infra antes do lançamento.

## 2. Fluxo ponta a ponta (opção recomendada, A)

```
App · Tela 04 "Redefina sua senha"
  1. Usuário digita o e-mail → validação local (vazio / formato)
  2. App: FirebaseAuth.instance.setLanguageCode('pt-BR')        ← idioma do e-mail e da página [C]; código exato aceito [NC]
  3. App: FirebaseAuth.instance.sendPasswordResetEmail(email: e) ← sem ActionCodeSettings no MVP
  4. Com enumeration protection: sucesso mesmo se a conta não existir [C]
     → App mostra "Confira seu e-mail" (texto neutro) + contador "Reenviar em 0:45"
Firebase Auth
  5. Se a conta existir, envia o e-mail do template "Password reset" [C]
     (não há erro avisando quando o e-mail NÃO é enviado [C])
E-mail
  6. Usuário toca no link → página padrão de ações do Firebase, no domínio do Hosting do projeto [C]
     (caminho exato e formulário de nova senha: [NC], ver seção 3)
Página padrão do Firebase
  7. Usuário define a nova senha → o código é consumido (uso único) [C]
  8. A página confirma a troca. Sem continueUrl, o usuário volta ao app sozinho
App · Tela 02 Login
  9. Entra com a nova senha (signInWithEmailAndPassword)
```

Dados tratados: só o e-mail digitado e, do lado do Google, os metadados técnicos da requisição. **O Nexo não grava nada no Firestore para esse fluxo.** O contador de reenvio é só local.

## 3. Onde a nova senha é criada: página padrão × tela do app

| Critério | **A. Página padrão do Firebase (recomendada no MVP)** | B. Tela "Nova senha" no app (deep link) |
|---|---|---|
| Como funciona | Link → handler web hospedado pelo Firebase [C] | `ActionCodeSettings(handleCodeInApp: true, …)`: o app recebe `oobCode` e chama `verifyPasswordResetCode` + `confirmPasswordReset` [C] |
| Código no app | Nenhum além da tela 04 | Tela nova, captura do link, 4 a 5 estados novos |
| Configuração | Nenhuma obrigatória | App Links (SHA-1/SHA-256, `intent-filter autoVerify`, `/__/auth/links`) + Universal Links (Associated Domains `applinks:<PROJECT_ID>.firebaseapp.com`) [C] + `firebase_auth` ≥ 5.5.0 [C] |
| E-mail aberto no computador | Funciona | Precisa de fallback web (de novo a página padrão ou um handler próprio) |
| App desatualizado ou não instalado | Funciona | Quebra ou cai na web |
| Visual | Fora do design system do Nexo; localizável [C]; personalização visual da página [NC] | 100% no design system, com a regra de senha visível (`validatePassword`) |
| Risco | Baixo | Médio: configuração de domínio por plataforma, mais casos para testar |

**Decidido (R1): A no MVP; B fica para depois do MVP.** Se no futuro quisermos a página web com a marca do Nexo, a saída oficial é um **handler próprio** hospedado no Firebase Hosting (`mode=resetPassword`, `oobCode`, `apiKey`, `continueUrl`, `lang`), configurado em Authentication › Templates › "customize action URL" [C]. Ele vale para **todos** os templates do projeto [C], então também cobre a verificação de e-mail da tela 05.

Pontos [NC] da opção A, a testar no projeto:
- se a página padrão mostra mesmo um formulário de nova senha (a doc só diz que o handler padrão trata "Resetting passwords");
- o caminho exato da URL;
- se a política de senha configurada é aplicada nessa página.

## 4. Deep link sem Dynamic Links

- **O Firebase Dynamic Links foi desligado em 25/08/2025 [C].** Os links `page.link` e de domínio custom retornam 404.
- O Auth gera os links mobile no domínio padrão do **Firebase Hosting** do projeto [C]. `dynamicLinkDomain` está deprecated e foi removido do `firebase_auth` 6.0.0 [C].
- `linkDomain` (disponível a partir do `firebase_auth` 5.5.0 [C]) só serve para domínio **custom** e não aceita `web.app` nem `firebaseapp.com` [C].
- **Na opção A nada disso é obrigatório**, porque o reset não depende de link mobile.
- **Na opção B (depois do MVP):**
  - Android: cadastrar SHA-1 e SHA-256 no console [C] e `intent-filter android:autoVerify="true"` para `https://<PROJECT_ID>.firebaseapp.com/__/auth/links` [C]. Se o Hosting publica o `assetlinks.json` automaticamente: [NC].
  - iOS: Associated Domains `applinks:<PROJECT_ID>.firebaseapp.com` [C]. O AASA já é publicado em todos os domínios do Hosting [C]. Se é preciso Team ID ou App Store ID no console: [NC].
- **Divergência registrada (não resolvida aqui):** as páginas Flutter "passing state" e "email link auth" ainda falam em Dynamic Links e `dynamicLinkDomain`. Já a versão Android e o changelog do `firebase_auth` dizem que isso foi removido. Vale o changelog e as páginas de migração.

## 5. Template do e-mail (Firebase Console › Authentication › Templates › Password reset)

O que dá para editar no console [C]: nome do remetente, endereço do remetente, reply-to, assunto e, **só no template de password reset**, o corpo.
Placeholders [C]: `%LINK%`, `%EMAIL%`, `%DISPLAY_NAME%`, `%APP_NAME%` (vem do "Public-facing name") e `%NEW_EMAIL%` (este só na troca de e-mail).
- A API do Identity Platform aceita `bodyFormat` HTML ou PLAIN_TEXT [C]. **Se o editor do console aceita HTML: [NC].** Por isso há duas versões abaixo.
- O idioma vem de `setLanguageCode` no app [C]. Se o console guarda um corpo separado por idioma: [NC].

### Mudanças em relação ao primeiro rascunho (aprovadas em 21/10/2026)

| Trecho aprovado | Proposta | Motivo |
|---|---|---|
| "Olá, %DISPLAY_NAME%." | "Olá!" | O comportamento com nome vazio é [NC]. Conta Apple pode chegar sem nome, e o resultado seria "Olá, ." |
| "O link vale por 1 hora" | "Por segurança, o link expira depois de um tempo e só pode ser usado uma vez." | O prazo de 1 hora não está na documentação oficial [NC]. Uso único [C] e expiração [C] estão |
| (não havia) | "Se ele não funcionar, peça um novo no app, em "Esqueci minha senha"." | Dá ao usuário a saída quando o link já expirou |

### Versão final proposta

- **Nome do remetente:** Nexo
- **Endereço do remetente:** `noreply@[DOMÍNIO DE ENVIO]`. Sem domínio próprio, fica o padrão `noreply@[PROJECT_ID].firebaseapp.com`.
- **Responder para:** `[E-MAIL DE CONTATO]`
- **Assunto:** Redefina sua senha do Nexo

Texto simples:

```
Olá!

Recebemos um pedido para redefinir a senha da sua conta do Nexo ligada a %EMAIL%.

Para criar uma nova senha, abra o link abaixo:
%LINK%

Por segurança, o link expira depois de um tempo e só pode ser usado uma vez. Se ele não funcionar, peça um novo no app, em "Esqueci minha senha".

Se você não pediu a redefinição, ignore este e-mail: sua senha atual continua valendo.

Equipe Nexo

Este é um e-mail automático. Para falar com a gente, escreva para [E-MAIL DE CONTATO].
```

HTML (só se o console aceitar; senão vale a versão acima):

```html
<p>Olá!</p>
<p>Recebemos um pedido para redefinir a senha da sua conta do Nexo ligada a <strong>%EMAIL%</strong>.</p>
<p><a href="%LINK%">Criar nova senha</a></p>
<p>Se o botão não abrir, copie e cole este endereço no navegador:<br>%LINK%</p>
<p>Por segurança, o link expira depois de um tempo e só pode ser usado uma vez. Se ele não funcionar, peça um novo no app, em "Esqueci minha senha".</p>
<p>Se você não pediu a redefinição, ignore este e-mail: sua senha atual continua valendo.</p>
<p>Equipe Nexo</p>
<p><small>Este é um e-mail automático. Para falar com a gente, escreva para [E-MAIL DE CONTATO].</small></p>
```

Os textos usam "Nexo" literal em vez de `%APP_NAME%`, para não depender do "Public-facing name" do console. Mesmo assim, configure esse campo como "Nexo" (seção 9).

### Remetente, domínio e Apple (pendência B5)

- **Domínio próprio de envio [C]:**
  1. Templates › lápis › "customize domain".
  2. Adicionar os registros TXT e CNAME que o console mostrar.
  3. Esperar a verificação (até 24 h).
  4. "Apply Custom Domain".
  - Só pode existir **um** registro `v=spf1` por domínio: se houver outro remetente, junte tudo nele [C].
  - DKIM: a página do Firebase não menciona [NC].
- **Apple Private Email Relay [C]:** para chegar a endereços `@privaterelay.appleid.com`, registre em Apple Developer › Email Sources o endereço `noreply@<PROJECT_ID>.firebaseapp.com` **ou** o domínio próprio do template.
  - A Apple exige SPF em todo domínio registrado [C].
  - O domínio do envelope (Return-Path) precisa casar com o registrado; se o provedor usar o próprio domínio no envelope, é preciso DKIM [C].
  - Remetente não registrado = e-mail devolvido [C].
  - Limite de fontes: 32 (conta individual) ou 100 (organização) [C].
- **SMTP próprio:** existe na API do Identity Platform (`SendEmail.smtp`) [C]. O passo a passo pelo console do Firebase e a necessidade de upgrade são [NC]. **Não recomendo no MVP.**

## 6. Segurança e privacidade

| Tema | Comportamento | Status |
|---|---|---|
| Enumeration protection | Ligada por padrão desde 15/09/2023. `sendPasswordResetEmail` não lança `user-not-found` e pode concluir com sucesso para e-mail inexistente | [C] |
| Mensagem da UI | Sempre neutra ("Se houver uma conta com…"). **Nunca** diga "conta não encontrada" | [D] |
| Link | Uso único; expira. Prazo exato a medir em teste | [C] / [NC] |
| Cota do projeto | Spark: 150 e-mails/dia e 1.500 links/dia. Blaze: 10.000 e-mails/dia e 100.000 links/dia. As cotas escalam com o número de usuários e podem mudar sem aviso | [C] |
| Limite por IP ou por endereço para reset | Não documentado. O Google pode ligar proteção contra abuso sem aviso | [NC] |
| Cooldown de 45 s | Só UX no app; não é controle de segurança. O controle real é a cota e a proteção do lado do Firebase | [D] |
| App Check | Authentication aparece como produto com enforcement, mas uma das páginas marca como "Preview". Replay protection não vale para Auth. O security checklist recomenda App Check + enumeration protection + cota mais apertada em `identitytoolkit.googleapis.com` | [C] (status Preview divergente) |
| Conta só com Google ou Apple | Se o e-mail é enviado e se a conta ganha o provedor "password" depois do reset: **[NC], testar**. A UI não pode revelar o provedor (enumeration) | [NC] |
| Uma conta por e-mail | Com a configuração ativa, um provedor confiável (Google em @gmail.com, Apple sempre) **sobrescreve** e-mail/senha **não verificado** | [C] |
| Senha removida nesse caso | Documentado só para login por link de e-mail | [NC] |
| E-mail não verificado | O reset funciona para a conta. O app continua exigindo a tela 05 depois do login (decisão do fluxo) | [D] |
| Logs | Erros vão para o Crashlytics como non-fatal **sem o e-mail** nem outro dado pessoal | [D] |
| Base legal | Envio do e-mail = **Contrato** (inventário §13); proteção contra abuso = **LI** (§1, §12). Nada novo a declarar na Política | [D], coerente com o inventário |

**Tela "Confira seu e-mail" (R7):** o usuário decidiu **não** acrescentar a dica para quem entra com Google ou Apple. A tela mantém o texto atual.

## 7. Estados e erros da UI

O `FirebaseAuthException.code` pode vir com ou sem o prefixo `auth/` (as páginas do pub.dev divergem) [NC]. **Normalize removendo `auth/` antes de comparar [D].**

### Tela 04 · pedir o link

| Situação / código | Origem | Mensagem (pt-BR) | Ação na UI |
|---|---|---|---|
| Campo vazio | validação local | "Informe o e-mail da sua conta." | Erro no campo |
| Formato inválido / `invalid-email` [C] | local + Firebase | "Confira o e-mail digitado. Ele parece incompleto." | Erro no campo |
| Sucesso (conta existe ou não) | Firebase [C] | "Confira seu e-mail" (texto atual) | Estado "Link enviado" + contador 0:45 |
| `user-not-found` (só se a proteção estiver desligada) [C] | Firebase | **Mesmo texto do sucesso** | Tratar como sucesso |
| `too-many-requests` | Firebase ([NC] neste método) | "Muitas tentativas. Aguarde alguns minutos e tente de novo." | Banner/Alert; desabilita o botão por 60 s |
| `network-request-failed` / sem conexão | Firebase ([NC] neste método) + checagem local | "Sem conexão com a internet. Verifique e tente de novo." | Alert com "Tentar de novo" |
| `missing-continue-uri`, `invalid-continue-uri`, `unauthorized-continue-uri`, `missing-android-pkg-name`, `missing-ios-bundle-id` [C] | configuração | "Não conseguimos enviar o link agora. Tente de novo em instantes." | Erro genérico + non-fatal no Crashlytics (sem e-mail) |
| Qualquer outro | — | Mesmo texto genérico | Idem |
| Reenviar | local | Snackbar "Link reenviado." | Reinicia o contador 0:45 |

### Opção B (só depois do MVP): tela "Nova senha" no app

| Código | Mensagem | Ação |
|---|---|---|
| `expired-action-code` [C] | "Este link expirou. Peça um novo para redefinir sua senha." | Botão "Pedir novo link" → tela 04 |
| `invalid-action-code` [C] | "Este link não vale mais. Ele pode já ter sido usado. Peça um novo." | Idem |
| `user-disabled` [C] | "Esta conta está desativada. Fale com a gente em [E-MAIL DE CONTATO]." | Sem retry |
| `user-not-found` [C] | Mesmo texto de `invalid-action-code` (neutro) | Idem |
| `weak-password` [C] / `password-does-not-meet-requirements` [NC no Flutter] | "A senha precisa seguir as regras abaixo." + lista da regra | Validar antes com `validatePassword` (`firebase_auth` ≥ 6.0.0) [C] |
| Sucesso | "Senha redefinida. Entre com a nova senha." | Vai para o Login com o e-mail preenchido (`verifyPasswordResetCode` devolve o e-mail [C]) |

## 8. Lacunas de design (para a sessão de prototipação)

A tela 04 tem hoje só **Default** e **Link enviado**. Para o MVP (opção A) faltam:
1. **Carregando** (botão "Enviar link" em loading).
2. **Erro de campo** (vazio / formato).
3. **Sem conexão** e **Muitas tentativas** (já existem no Login; reaproveitar o padrão).
4. **Erro genérico**.
5. Snackbar **"Link reenviado."**

As telas da opção B (Nova senha, Link expirado/inválido, Senha redefinida) **não** devem ser desenhadas agora.

## 9. Decisões e tarefas de configuração (para a sessão de infra)

### Decisões do usuário

| # | Decisão | Status |
|---|---|---|
| R1 | Onde criar a nova senha | **Decidido:** A, página padrão do Firebase, no MVP; B depois |
| R2 | Remover "1 hora" do e-mail | **Decidido:** sim, até medir em teste |
| R3 | Saudação | **Decidido:** "Olá!" sem `%DISPLAY_NAME%` |
| R4 | Domínio próprio de envio no lançamento | **Aberta.** Recomendação: enquanto não houver domínio, usar `noreply@<PROJECT_ID>.firebaseapp.com` com o nome "Nexo" e migrar depois |
| R5 | Regra de senha | **Aberta.** Recomendação: igual à regra mostrada na tela 03 Cadastro, com a política do Firebase em Require e o mesmo mínimo |
| R6 | Plano do Firebase antes do lançamento público | **Aberta.** Recomendação: Blaze, por causa da cota de 150 e-mails/dia no Spark |
| R7 | Texto extra para contas Google/Apple na tela "Link enviado" | **Decidido:** não |

### Tarefas de configuração (infra)

1. Confirmar que a **email enumeration protection** está ligada (Authentication › Settings).
2. Definir **Public-facing name** = "Nexo".
3. Template **Password reset**: remetente, assunto e corpo da seção 5; idioma padrão pt-BR.
4. App: `setLanguageCode('pt-BR')` antes do envio. Confirmar em teste o código aceito.
5. **Apple Developer › Email Sources:** registrar `noreply@<PROJECT_ID>.firebaseapp.com` (ou o domínio próprio) e conferir o SPF (B5).
6. Domínio próprio (quando houver): TXT/CNAME do console e um único registro SPF.
7. **Política de senha** em Require (R5); no app, `validatePassword` antes de enviar.
8. **App Check** com enforcement em Authentication e cota apertada em `identitytoolkit.googleapis.com` (security checklist).
9. `firebase_auth` em versão atual (7.x), sem `dynamicLinkDomain`.
10. Só na opção B: App Links, Universal Links, `ActionCodeSettings(handleCodeInApp: true)` e domínio em Authorized domains.

### Testes para fechar os [NC] (em projeto de teste, com contas de teste)

- [ ] Prazo real de expiração do link.
- [ ] Resultado de `%DISPLAY_NAME%` vazio.
- [ ] Se o editor do console aceita HTML.
- [ ] Se a página padrão mostra o formulário de nova senha e aplica a política de senha.
- [ ] Conta só Google/Apple: o e-mail chega? A conta ganha o provedor "password"?
- [ ] `too-many-requests` e `network-request-failed` em `sendPasswordResetEmail`; prefixo `auth/` no código.
- [ ] Código de idioma aceito (`pt-BR` × `pt`).
- [ ] Entrega para `@privaterelay.appleid.com` com o remetente registrado.

## 10. Referências oficiais (consultadas em 20–21/10/2026)

- Templates e placeholders: https://support.google.com/firebase/answer/7000714
- Domínio próprio de envio: https://firebase.google.com/docs/auth/email-custom-domain
- Limites e cotas: https://firebase.google.com/docs/auth/limits
- Handler de ações (custom e padrão): https://firebase.google.com/docs/auth/custom-email-handler
- REST (`sendOobCode`, `resetPassword`, `EXPIRED_OOB_CODE`, `INVALID_OOB_CODE`): https://firebase.google.com/docs/reference/rest/auth
- Identity Platform Config (`bodyFormat`, SMTP, `defaultLocale`): https://docs.cloud.google.com/identity-platform/docs/reference/rest/v2/Config
- Email enumeration protection: https://docs.cloud.google.com/identity-platform/docs/admin/email-enumeration-protection
- Política de senha: https://docs.cloud.google.com/identity-platform/docs/password-policy
- Dynamic Links FAQ: https://firebase.google.com/support/dynamic-links-faq
- Migração de links mobile (Android / iOS): https://firebase.google.com/docs/auth/android/email-link-migration · https://firebase.google.com/docs/auth/ios/email-link-migration
- Estado em ações de e-mail: https://firebase.google.com/docs/auth/android/passing-state-in-email-actions
- FlutterFire API: `sendPasswordResetEmail`, `verifyPasswordResetCode`, `confirmPasswordReset`, `checkActionCode`, `setLanguageCode`, `validatePassword`, `ActionCodeSettings` em https://pub.dev/documentation/firebase_auth/latest/ e changelog em https://pub.dev/packages/firebase_auth/changelog
- Erros no Flutter: https://firebase.google.com/docs/auth/flutter/errors
- Contas e provedores confiáveis: https://firebase.google.com/docs/auth/users
- Sign in with Apple (Firebase): https://firebase.google.com/docs/auth/ios/apple
- Apple Private Email Relay: https://developer.apple.com/help/account/capabilities/configure-private-email-relay-service/
- Security checklist: https://firebase.google.com/support/guides/security-checklist
- App Check: https://firebase.google.com/docs/app-check · https://firebase.google.com/docs/app-check/enable-enforcement
