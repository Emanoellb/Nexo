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

## Sincronizado

(nada ainda)
