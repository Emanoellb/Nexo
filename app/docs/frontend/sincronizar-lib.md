# Mudanças feitas no Flutter para levar ao `nexo.lib.pen`

Regra temporária decidida pelo usuário em 26/10/2026: com o MCP do Pencil pausado até 28/10/2026, tokens e componentes novos ou ajustados nascem no Flutter. **Em 28/10/2026, tudo o que estiver em "Pendente" vai para a lib.** Depois disso, cada item passa para "Sincronizado", com a data.

Legenda: **[D]** decisão do usuário · **[P]** proposta do agente, a revisar no design.

## Pendente

### `Navigation/NavigationBar` (branch `chore/estrutura-riverpod-router`, 26/10/2026)

Código: `app/lib/core/ui/navigation/nexo_navigation_bar.dart` e `app/lib/app/shell/nexo_shell.dart`.

| Item | No Flutter | Origem |
|---|---|---|
| Destinos | 5, nesta ordem: Início · Tarefas · Planos · Calendário · Perfil | [D] |
| Destino central | **Planos sem botão elevado**: um destino igual aos outros. Substitui `Navigation/NavigationBarItem/Center` (Primary elevado) | [D] |
| Nome do destino | Visível **só no selecionado**; todos têm nome acessível ("Planos, aba 3 de 5") | [D] |
| Ícones Lucide | `house`, `list-todo`, `target`, `calendar-days`, `user` (provisórios) | [P] |
| Vidro ("Nexo Glass") | Fundo `Glass/Fill` + brilho `Glass/Sheen` → `Glass/SheenEnd` (de cima para baixo), borda `Glass/Edge`, desfoque `Glass/Blur` (24), sombra `Elevation/2`, forma `Shape/Full` | [D] vidro · [P] composição |
| Selecionado (vidro) | Pílula `Glass/Indicator` + ícone e nome em `Glass/ContentSelected` | [P] |
| Não selecionado (vidro) | Ícone em `Glass/Content` | [P] |
| Versão sólida | Ativa com contraste alto do sistema ou com "reduzir transparência" do app. Fundo `Glass/Fallback`, borda `OutlineVariant`, pílula `Selected`, ícones não selecionados em `Icon/Secondary` | [D] existência · [P] cores |
| "Reduzir transparência" | O Android não expõe a preferência do sistema ao Flutter [NC]. Vira um ajuste do app no Perfil (bloco 11); começa desligado | [P] |
| Medidas | Alvo de 48 × 48; margens `Spacing/LG` nas laterais e `Spacing/SM` embaixo (acima da área segura); padding interno `Spacing/XS`; pílula com `Spacing/LG` nas laterais quando selecionada | [P] |
| Fonte ampliada | O nome do selecionado é cortado com reticências em vez de estourar a barra | [P] |
| Movimento | Troca de destino com `Motion/Duration/Short` + `Motion/Easing/Standard`; parado com "reduzir movimento" | [P] |

### Splash, tela 01 do `nexo.app.pen` (branch `feat/splash-tutorial`, 26/10/2026)

Código: `app/lib/features/splash/`, `app/lib/core/ui/brand/nexo_animated_symbol.dart` e `app/android/app/src/main/res/`.

| Item | No Flutter | Origem |
|---|---|---|
| Splash nativa | Fundo `Surface` e símbolo estático de 128 dp. No Android 12+ usa a SplashScreen API, com o ícone dentro do círculo de 192 dp. Sem animação nativa | [D] |
| Animação | O "x" é revelado a partir dos traços do SVG oficial: reto 0–800 ms, curvo 550–1500 ms, `Motion/Easing/Emphasized`; depois o símbolo pronto fica até 2,7 s (alongado em +2 s em 27/10/2026, pedido do usuário) | [D] roteiro |
| 1ª abertura | "Bem-vindo ao Nexo" (TitleLarge) e "Do objetivo à ação do dia." (BodyMedium, OnSurfaceVariant) abaixo do símbolo, de 1100 a 1500 ms (`Enter`, sobe `distanceMedium`), mais ~600 ms de leitura: 3,3 s no total. Marca local `first_open_done` | [D] |
| Saída | Sem sessão: Hero até a logo do Login (tag `nexo-logo`; a tela de Login deve usar a mesma). Com sessão: esmaecimento até o Início (`Motion/Duration/Medium`) | [D] |
| Reduzir movimento | Símbolo e texto estáticos; só a pausa de leitura na 1ª abertura | [D] |
| Modo escuro do sistema | A abertura continua clara, porque o app é só claro | [P] |

### Tutorial: conteúdo novo dos 5 passos (decidido em 26/10/2026; ainda não implementado)

O `nexo.app.pen` (tela 06) e o `AGENTS.md` §2 descrevem o tutorial antigo. Os passos novos são:
1. Objetivo + Plano;
2. Tarefas + Calendário;
3. Início;
4. Sessão de foco;
5. Progresso + Pontos.

Também mudam (implementado no app em 28/10/2026, branch `feat/tutorial`):
- títulos: Objetivo e plano · Tarefas e calendário · Seu dia no Início · Sessão de foco · Seu progresso; o passo 1 traz "Boas-vindas, {nome}";
- topo com o "ne×o" (24 px) e "Pular"; rodapé com o PageControl de 5 pontos e "Próximo";
- botão "Repetir animação" (ícone `rotate-ccw`) no canto da ilustração, escondido com "reduzir movimento";
- **tela de fechamento "Tudo pronto"** depois do passo 5 (não conta como passo): só o símbolo do Nexo, que se desenha; "Seu objetivo e a ação do dia, no mesmo lugar."; botão "Começar" (grava `tutorialSeen` e leva ao Início);
- "Pular" (passos 1–5) leva ao "Tudo pronto". As 3 saídas antigas do passo 5 (Criar uma tarefa, Criar um plano, Explorar o app) saíram; `firestore-rules.md` §4 ainda cita "as 3 saídas do passo 5".

### Input: erro em campo com ação própria (decidido em 27/10/2026)

`Input/TextField` e `Input/Date` (`d:ds8UE`): no estado Error, um campo com ação própria (olho da senha, calendário) **mantém a ação** e não mostra o ícone de erro. O erro fica na borda Error de 2 px e no texto de apoio. Campo sem ação própria segue com o ícone de erro. No Flutter: `NexoTextField` (`trailing`, `obscurable`) e o `NexoDateField`, novo.

### Telas de entrada (app, não a lib; decidido em 27/10/2026)

Para a sessão de prototipação levar ao `nexo.app.pen`:
- Login: o "ne×o" (`nexo-nome-integrado-claro.svg`) no topo, com 24 px de altura e 24 px abaixo da barra de status; o formulário fica centralizado na altura livre.
- 03b: seta de voltar no topo no lugar de "Cancelar e sair" (mesma ação).

## Sincronizado

(nada ainda)
