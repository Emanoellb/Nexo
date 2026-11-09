# Tokens do Nexo → Flutter

Fonte: variáveis de `pen.dev/nexo.lib.pen` (fora do repositório), lidas em 21/10/2026 pelo MCP do Pencil e de novo em 04/11/2026, com o tema escuro. O código fica em `app/lib/core/theme/`.

## Regras

1. **Widgets nunca usam cor literal nem primitiva.** As cores vêm de `Theme.of(context).colorScheme` (papéis do Material 3) ou de `context.nexoColors` (papéis do Nexo que o `ColorScheme` não tem).
2. **Os valores ficam num lugar só.** Cores em `nexo_colors.dart`, com os valores copiados da lib. Espaçamento, forma, sombra e movimento em `nexo_dimensions.dart`. Texto em `nexo_typography.dart`.
3. **Fonte da verdade: a lib.** Mudou um token na lib, atualize aqui. A regra temporária de 26/10/2026 (tokens nascendo no Flutter enquanto o Pencil estava fora) foi encerrada em 28/10/2026; o histórico fica em [`sincronizar-lib.md`](sincronizar-lib.md). Exceção pontual: `Spacing/2XS` e `Size/Target` (04/11/2026) entraram no Flutter junto com o pedido para a lib; quando a lib os tiver, confira os valores.
4. **Claro e escuro (04/11/2026):** `NexoColors.light` e `NexoColors.dark` têm os mesmos campos, e `NexoTheme.light()` / `NexoTheme.dark()` montam o tema com eles. Nenhum widget lê `light` ou `dark` direto: todos leem os papéis semânticos, então servem aos dois temas.
   - **Tema do app:** segue o sistema por padrão. A escolha Sistema · Claro · Escuro fica em `themePreferenceProvider` (`core/theme/theme_preference.dart`), guardada só no aparelho (`theme_preference`). A opção na tela vem com o Perfil.
   - **Sombras iguais nos dois temas** (`NexoElevation.standard`): no escuro, a elevação aparece pelo tom mais claro da superfície e pela borda; diálogos e painéis sem borda se separam pelo tom e pelo scrim.
   - **`ColorScheme` definido à mão, sem `ColorScheme.fromSeed`:** no escuro, `SurfaceContainerLowest` (`#262A31`) é mais claro que `Surface` (`#14171B`), porque no Nexo ele é a superfície elevada (cartões, menus, diálogos, campos, Snackbar). No M3, o Lowest escuro seria o mais escuro.

**Exceção à regra 1 (26/10/2026; escuro em 04/11/2026):** a splash nativa do Android precisa de cor em hex, porque o XML do Android não lê os tokens do Flutter.

| Arquivo | `nexo_splash_background` | `nexo_splash_symbol` |
|---|---|---|
| `res/values/colors.xml` (claro) | `Surface` `#FAFAFB` | `Brand/Mark` `#567792` |
| `res/values-night/colors.xml` (escuro) | `Surface` `#14171B` | `Brand/Mark` `#6E92AE` |

A splash segue o tema do **app** (`Surface` `#14171B`), não os `Brand/*` locais da logo (`Brand/Surface` `#1D2127`, letras `#FAFAFB`), que valem só para os SVGs e o pacote da marca. O Android escolhe pelo modo do sistema, antes de o app abrir: com "Claro" ou "Escuro" forçado no app ao contrário do sistema, a abertura nativa segue o sistema e o Flutter troca para o tema escolhido no primeiro quadro. Daí em diante, o `WindowBackgroundSync` (`lib/app/window_background.dart`) põe o fundo da janela nativa no `Surface` do tema ativo, pelo canal `nexo/window` da `MainActivity`, para a janela não aparecer no outro tema em redimensionamentos e transições.

Se esses tokens mudarem, atualize também esses arquivos.

## Acesso no código

| Token da lib | Flutter |
|---|---|
| `Colors/Semantic/*` (papéis do M3) | `Theme.of(context).colorScheme.<papel>` |
| `Colors/Semantic/*` (todos, inclusive Success, Warning, Info, Card, Glass, Icon, Control, Disabled, Hover, Pressed, Focus, Selected) | `context.nexoColors.<campo>` |
| `Typography/*` | `Theme.of(context).textTheme.<slot>` ou `NexoTextStyles.<papel>` |
| `Spacing/*` | `context.spacing.xxs … xxxxl` (`xxs` = `Spacing/2XS` = 2, desde 04/11/2026: título e texto do aviso, barras do tutorial) |
| `Size/Target` (novo, 04/11/2026) | `context.sizes.target` (48): alvo mínimo de toque e altura dos controles (botão, campo, Snackbar, checkbox, IconButton, avatar do topo, indicador de páginas) |
| Ícones | Só 24, 20 e 16 (AGENTS.md §6). O ícone de "e-mail confirmado" (era 32) e o check da caixinha do tutorial (era 14) foram ajustados em 04/11/2026 |
| `Shape/*` | `context.shape.xs … full` |
| `Elevation/0..5` | `context.elevation.level(n)` (lista de `BoxShadow`) |
| `Motion/*` | `context.motion.short`, `.standard` (`Cubic`), `.distanceSmall`… |
| `Motion/Easing/*` (valores M3 desde 08/11/2026, nomes iguais) | `standard` = `Cubic(0.2, 0, 0, 1)` (M3 standard); `enter` = `Cubic(0.05, 0.7, 0.1, 1)` (emphasized decelerate); `exit` = `Cubic(0.3, 0, 0.8, 0.15)` (emphasized accelerate); `emphasized` = `Curves.easeInOutCubicEmphasized` (curva de 3 pontos, não cabe numa cúbica). Ao fechar, a curva vem com `.flipped` (acelera na saída). Antes eram as curvas do M2 (transições §8.2) |
| `Motion/Distance/Page` (novo, 08/11/2026) | `context.motion.distancePage` (30, o valor do M3): eixo compartilhado X (detalhes, Perfil, legais, Auth e passos do Criar plano). O `distanceLarge` (16) continua no subir com esmaecimento |
| `Motion/Scale/Enter` (novo, 08/11/2026) | `context.motion.scaleEnter` (0,92): escala inicial de quem entra no fade through (troca de aba) e no diálogo (padrão de transições, `pen.dev/notas/transicoes-especificacao.md`) |
| `Motion/Duration/Pulse` e `Motion/Opacity/PulseMin` (novos, 05/11/2026) | `context.motion.pulse` (1050 ms, meio ciclo do pulso) e `context.motion.pulseMinOpacity` (0,55): pulso do `NexoSkeleton`, que fica parado com "reduzir movimento" |
| `Glass/Blur` | `context.glass.blur` (24). As cores `Colors/Semantic/Glass/*` ficam em `context.nexoColors.glass*`; as de repouso (`Glass/Rest/*`) em `glassRestFill`, `glassRestSheen`, `glassRestEdge` |
| `Colors/Semantic/Unread` (novo, 04/11/2026) | `context.nexoColors.unread`: fundo da linha de aviso não lido. Claro `#F7F8F9` (igual ao antigo SurfaceContainerLow), escuro `#30353D` (mais claro que o cartão `#262A31`) |
| `Colors/Semantic/StepMarker/Border` (novo, 05/11/2026) | `context.nexoColors.stepMarkerBorder`: borda de 1 px do marcador das etapas futuras dos "Primeiros passos" do Início. Claro `#F4F5F7` (igual ao fundo, não aparece); escuro `#858B96`, 4,7:1 sobre o Card/Default `#1D2127`, onde o SurfaceContainer do círculo se confunde com o cartão |
| `Colors/Semantic/Brand/Mark` | `context.nexoColors.brandMark`: cor do símbolo. Claro = Primary/600 `#567792`; escuro = Primary/500 `#6E92AE`, **diferente do Primary escuro** (`#B8CBDC`) |
| `Elevation/0..5` nos dois temas | `NexoElevation.standard` (uma só lista: a cor da sombra é a mesma) |
| `typeface` (Manrope) | `nexoFontFamily`, empacotada em `assets/fonts/` (SIL OFL 1.1) |

## ColorScheme (Material 3)

| Campo do ColorScheme | Token da lib | Observação |
|---|---|---|
| primary / onPrimary / primaryContainer / onPrimaryContainer | Primary / OnPrimary / PrimaryContainer / OnPrimaryContainer | |
| secondary / onSecondary / secondaryContainer / onSecondaryContainer | Secondary / … | |
| tertiary / onTertiary / tertiaryContainer / onTertiaryContainer | **alias de Secondary** | A lib não tem Tertiary |
| error / onError / errorContainer / onErrorContainer | Error / … | |
| surface / onSurface / onSurfaceVariant | Surface / OnSurface / OnSurfaceVariant | |
| surfaceDim | SurfaceDim | No claro, mesmo valor de SurfaceContainer (`#F4F5F7`); no escuro, mesmo valor de Surface (`#14171B`) |
| surfaceBright | **alias de Surface** | |
| surfaceContainerLowest … High | SurfaceContainerLowest … High | |
| surfaceContainerHighest | **alias de SurfaceContainerHigh** | |
| outline / outlineVariant | Outline / OutlineVariant | Outline/Surface = 2,02:1. Contorno de campo usa `Control/Border` |
| shadow | OnSurface | Cor-base das sombras da lib (Neutral/900) |
| scrim | Scrim | |
| inverseSurface / onInverseSurface | OnSurface / Surface | Igual ao botão Apple da lib. Snackbar, Dialog, menus e painéis **não** usam: ficam em `SurfaceContainerLowest` nos dois temas, nunca invertidos |
| inversePrimary | **alias de PrimaryContainer** | Sem token na lib |
| surfaceTint | transparente | O Nexo usa sombra, não tinta de elevação |

**Transparente nos widgets:** a lib não tem papel "transparente" e os widgets não usam `Colors.transparent`. Onde é preciso uma cor invisível (fundo do SnackBar do Flutter, camada de toque em repouso, barreira sem scrim), usa-se o próprio token do contexto com `withValues(alpha: 0)`, ou `MaterialType.transparency`.

Os aliases são escolhas desta sessão e não aparecem no design. Se a lib ganhar esses papéis, troque aqui.

## TextTheme (Material 3)

A lib tem 9 papéis e o M3 tem 15. Peso 600 = `Typography/Weight/Emphasis`. Sem letter-spacing na lib, então fica 0.

| Slot M3 | Papel da lib | Tamanho / peso / altura | Quem usa |
|---|---|---|---|
| displayLarge, displayMedium\*, displaySmall\* | DisplayLarge | 32 / 700 / 1,25 | |
| headlineLarge | HeadingLarge | 28 / 700 / 1,29 | |
| headlineMedium, headlineSmall\* | HeadingMedium | 24 / 600 / 1,33 | Título do Dialog |
| titleLarge | TitleLarge | 20 / 600 / 1,4 | |
| titleMedium | TitleMedium | 18 / 600 / 1,33 | Título da TopAppBar |
| titleSmall\* | LabelMedium + Emphasis | 14 / 600 / 1,43 | |
| bodyLarge | BodyLarge | 16 / 400 / 1,5 | |
| bodyMedium | BodyMedium | 14 / 400 / 1,43 | Valor dos campos, texto de Snackbar/Alert/Dialog |
| bodySmall\* | LabelSmall | 12 / 500 / 1,33 | Helper e erro dos campos |
| labelLarge | LabelMedium + Emphasis | 14 / 600 / 1,43 | Rótulo de botão |
| labelMedium | LabelMedium | 14 / 500 / 1,43 | Rótulo de campo e de checkbox |
| labelSmall | LabelSmall | 12 / 500 / 1,33 | |
| — | DisplayTimer | 56 / 600 / 1,14 | `NexoTextStyles.displayTimer` (Nexo/FocusTimer) |

\* alias: o slot repete o papel mais próximo.

**Atenção:** a Manrope é uma fonte variável. Cada estilo define o peso em `fontWeight` e no eixo `wght` (`FontVariation.weight`). Um `copyWith(fontWeight: …)` feito fora do tema não ajusta o eixo. Use os estilos do tema ou ajuste os dois. A renderização de cada peso ainda não foi verificada em dispositivo.

**Negrito do sistema (05/11/2026):** com "texto em negrito" ligado no aparelho (`MediaQuery.boldTextOf`), todo estilo ganha +200 de peso, até 800 (máximo da Manrope), no `fontWeight` e no eixo `wght` (`withBoldText`). O app aplica ao tema no `builder` do `MaterialApp` (`NexoTheme.withSystemText`). Estilo fixo de `NexoTextStyles` usado direto num widget passa por `context.textStyle(...)`, nunca sozinho.

## Decisão de componente que afeta o tema

Na lib, o rótulo do campo fica **acima** do campo (LabelMedium) e o valor usa BodyMedium (14). Não é o rótulo flutuante do Material. O `InputDecorationTheme` e o `TextField` do Nexo (fase 3) seguem a lib.

## Desvios intencionais do Material 3

Decisões da lib (pen.dev), registradas em 05/11/2026 na auditoria de componentes. Não são erro de implementação; não "corrija" para o padrão do M3.

| Componente | Material 3 | Nexo (lib) | Por quê |
|---|---|---|---|
| Botão (Primary, Secondary, Tertiary) | 40 de altura, formato pílula | 48 de altura (`Size/Target`), `Shape/MD` (12) | Alvo de toque ≥ 48 também na altura; cantos iguais aos dos cartões e campos |
| Campo de texto | 56 de altura, rótulo flutuante | 48, rótulo **acima** (LabelMedium) | Rótulo sempre visível (mais claro com leitor de tela e fonte grande) |
| Snackbar | Superfície invertida (escura no claro) | Superfície elevada do tema (`SurfaceContainerLowest`), com borda e Elevation/3, nunca invertida | Superfícies neutras nos dois temas |
| Barra de navegação | Barra de 80 encostada na base, indicador só atrás do ícone | Cápsula flutuante de vidro (64), indicador atrás do item inteiro, nome sempre visível, versão sólida | Vidro adaptativo do Nexo; "reduzir transparência" e alto contraste usam a sólida |
| FAB | 56, `Shape` 16 | 64, redondo (`Shape/Full`), ao lado da cápsula | Criação pelo "+" da barra; abre o menu do "+" (como o FAB menu do M3 Expressive) |
| Dialog | Raio 28 | `Shape/LG` (16), 312 de largura, ícone e título alinhados à esquerda | Mesma família de raios do app |
| Checkbox | Caixa de 18 | Caixa de 20 (`Shape/XS`, borda 2 em `Control/Border`), alvo de 48 | Leitura melhor com a borda de 2 px |
| Segmented (`NexoSegmented`) | 40 de altura | Faixa de 48 (`Size/Target`) com a pílula de 40 dentro (padding XS); a faixa inteira é o alvo (a lib desenha 44) | Alvo ≥ 48 |
| Chip de filtro (`NexoFilterChip`) | 32 de altura | Visual de 36 (`Shape/SM`) num alvo de 48 (a lib desenha 44); selecionado com check + PrimaryContainer | Alvo ≥ 48; estado não depende só da cor |
| Bottom sheet (`showNexoBottomSheet`) | Raio 28 | `Shape/XL` em cima, Elevation/3, alça 32 × 4 com alvo de 48 ("Fechar" no leitor de tela), título TitleMedium; abre no navegador raiz, por cima da barra de abas | Dentro de uma aba, a barra de vidro ficaria por cima do painel |
| Abas (`NexoTabs`) | Indicador das abas principais sob o conteúdo | Igual ao M3 e à lib: indicador de 3 px só sob rótulo e contagem; papéis `tabBar`/`tab` | — |
| Menu (`showNexoMenu`) | Raio 4 | `Shape/MD`, 256; posição pelo tamanho medido (abaixo; acima se não couber; senão dentro da tela, com rolagem); foco com anel interno | Fonte ampliada não corta o menu |

## Comportamento de sistema

- **Snackbar com ação** ("Desfazer"): some em 4 s, como no design. Com leitor de tela ativo (`MediaQuery.accessibleNavigationOf`), **não some sozinha** (`SnackBar.persist`) e ganha o botão Fechar (WCAG 2.2.1 e M3). `queue: true` entra na fila sem apagar a atual; `clearQueue: true` aparece na frente de tudo ("Primeiros passos concluídos.").
- **Vibração**: só ao concluir uma tarefa (e, quando existirem, ao concluir um plano e um objetivo), leve (`HapticFeedback.lightImpact`), seguindo a configuração de vibração do sistema. Nada no "+" (decisão do usuário, 05/11/2026).
- **Fonte ampliada**: os testes de layout cobrem 1,3 e 2,0 (o Android vai até 200%). Textos em linha usam `Wrap`/`Flexible`; as ações do cartão do plano empilham quando o Tertiary não cabe ao lado sem espremer o Focar.
- **Excluir com "Desfazer"** (Tarefas e Disciplinas, design de 04/11/2026): sem confirmação. O item some na hora em todas as telas (`visibleTasksProvider` / `visibleSubjectsProvider`) e só é apagado quando a Snackbar some sem o toque em "Desfazer" (`deleteWithUndo` + `DeferredDeletion`). Presa à conta: trocar de conta antes do fim não apaga nem devolve nada na conta nova. Excluir uma disciplina mantém as tarefas, sem disciplina.
- **Adiar para amanhã**: só em tarefa pendente com prazo até hoje (atrasada ou de hoje). De amanhã em diante, a ação não aparece (manteria ou adiantaria o prazo).
- **"Agora" das telas com prazo**: `screenNowProvider`, renovado à meia-noite e no próximo prazo (`ScreenNowRefresh`) no Início, em Tarefas e no detalhe da disciplina: a tarefa vira "Atrasada" sozinha.
- **Carregando**: `NexoDelayedSkeleton` (skeleton só depois de 300 ms) e `NexoSkeletonList` (bloco de lista), usados no Início e em Tarefas.
- **Medidas de componente sem token na lib**: linha "Adicionar disciplina" com 56 de altura e ponto de 8 no botão "Visualização" (valores do design de Tarefas); ações do deslizar com 80 de largura (Concluir a 20 da borda).
- **Deslizar na tarefa** (`NexoSwipeActions`): à direita conclui (fundo Success); à esquerda revela Adiar (PrimaryContainer) e Excluir (Error). As mesmas ações ficam no toque longo (menu) e no leitor de tela (ações personalizadas, num nó por linha). Espelha em idioma da direita para a esquerda. Sem animação com "reduzir movimento".
- **Botões destrutivos**: `NexoButton.destructiveHigh` (Error/OnError, confirmação de ação irreversível num Dialog: `showNexoDialog(destructive: true)`) e `NexoButton.destructiveLow` (texto Error, ex.: "Excluir disciplina" no formulário).
- **Disciplina sem cor**: o modelo é `{name, icon}`; a cor por disciplina saiu do MVP (regras v0.8 negam `color`). O ícone é um dos 12 do cadastro.
- **Saudação do Início** (adendo do pacote B, 05/11/2026): `NexoTabHeader(greeting: greetingOf(nome))`, só na aba Início. Duas linhas nos mesmos 64: "Olá, {primeiro nome}" (TitleLarge, OnSurface) e "Início" (BodyMedium, OnSurfaceVariant), uma linha cada, com reticências; lidas como um cabeçalho ("Olá, Ana. Início"). Sem nome: "Olá". As outras abas mantêm o título (HeadingMedium).
- **Lista em cartão**: `NexoCardList` (= `Content/List` num `NexoCard` com divisores OutlineVariant e recuo LG), usada no Início e em Tarefas. Segue as telas aprovadas do `nexo.app.pen` (`Shape/LG`, sem padding vertical), não o `Content/List` da lib (`Shape/MD` + padding XS): conferido em 05/11/2026.
- **Linha da disciplina**: `NexoProgressRow` (nome, "x de y entregas", barra, próxima entrega em Error se atrasada) e o chevron, sem ícone (telas aprovadas de Tarefas 11). A mesma linha é usada nos planos e nos objetivos. O ícone escolhido no cadastro ainda não aparece em nenhuma tela.
- **Calendário do plano**: o dia com horas registradas à mão ("Registrar horas", até 7 dias atrás) ganha um lápis de 12 em Primary no canto do número (`NexoCalendarDay(manual: true)`), a legenda "Registro manual" e, no leitor de tela, "com registro manual". O resumo do dia diz "1 sessão · 1 registro manual" (pedido do usuário, 09/11/2026).
- **Cartão tocável**: `NexoCard(onTap:)` usa o `NexoTappable` com a mesma decoração. O plano principal do Início abre o detalhe do plano; os botões de dentro mantêm o próprio toque.
- **Cartão**: `NexoCard` (= `Content/Card`: Card/Default, borda Card/Border, `Shape/MD`, padding LG). Não repita a decoração à mão.
- **Foco** (design de 07/11/2026, `pen.dev/notas/foco-especificacao.md`): `NexoFocusTimer` (= `Nexo/FocusTimer`: rótulo LabelSmall 600, tempo em `DisplayTimer` com algarismos tabulares, OnSurfaceVariant quando pausado, barra do dia de 240 em Secondary; o leitor de tela lê tudo num nó, sem anunciar cada segundo), `NexoFocusBar` (= `Navigation/FocusBar`: 64, SurfaceContainerLowest, borda Card/Border, `Shape/LG`, Elevation/2, a 16 das laterais e acima da barra de abas) e `NexoAssistChip` (= `Chip/Assist`: visual de 36 num alvo de 48; com fonte ampliada o rótulo quebra e o chip cresce). Tópicos da sessão: `Chip/Input` + "Adicionar tópico", até 3.
  - O cronômetro é local (início e pausas no `LocalFlags`, por conta) e a sessão só vai ao Firestore ao encerrar, dividida à meia-noite (`splitSessionByDay`). Menos de 1 min não é salvo.
  - Partes nativas (aprovadas em 09/11/2026), atrás da interface `FocusSystem` (`AndroidFocusSystem` no Android; `NoopFocusSystem` no iPhone e nos testes, sem o interruptor):
    - **Notificação fixa**: `flutter_local_notifications` 22.3.x (a 23 exige compileSdk 37), canal "Foco" (importância baixa, silenciosa), sem botões e **sem foreground service**. Rodando, o sistema conta o tempo (`usesChronometer`); pausada, o tempo parado vai no título. Tocar abre o foco (depois do Login, se preciso). POST_NOTIFICATIONS é pedida no primeiro foco. Ícone: `ic_splash_symbol`. O desugaring do Gradle é exigência do pacote. A VIBRATE que o pacote traz foi removida do manifesto (`tools:node="remove"`).
    - **"Não perturbe"**: canal Kotlin `nexo/focus` no `MainActivity` (ACCESS_NOTIFICATION_POLICY, sem pacote de terceiros). Liga o modo prioridade e guarda o estado de antes; desliga ao encerrar ou descartar e, se o app tiver fechado à força, na próxima abertura (`AndroidFocusSystem.init`, durante a splash). Se a pessoa mudou o modo no meio do foco, o dela fica. O painel da tela 03 avisa: "O “Não perturbe” é desligado quando você encerra o foco ou reabre o app." "Permitir durante o uso do app" fica lembrado por conta (`LocalFlags.dndAllowed`); "Apenas esta vez" pergunta de novo no próximo foco.

## Transições entre telas

Fonte: `pen.dev/notas/transicoes-especificacao.md`, aprovada pelo usuário em 08/11/2026. Código: `app/lib/app/router/nexo_transitions.dart` (`NexoTransitionPage` / `NexoPageMotion`) e `app/lib/app/shell/fade_through_branches.dart`.

| Navegação | Transição | Código |
|---|---|---|
| Troca de aba | Fade through: sai esmaecendo nos primeiros 35%; entra esmaecendo e crescendo de `scaleEnter` (0,92) a 1 nos 65% finais · Medium · Standard. O estado de cada aba é mantido | `FadeThroughBranches` no `navigatorContainerBuilder` |
| Detalhe dentro da aba, detalhe da tarefa, Perfil, Termos, Privacidade e Auth | Eixo compartilhado X: entra da direita (`distancePage`, 30) esmaecendo; a tela de baixo vai para a esquerda (−30) | `NexoPageMotion.sharedAxisX` |
| Criar ou editar por cima das abas | Sobe esmaecendo; a tela de baixo não se move | `NexoPageMotion.slideUp` |
| Foco | Sobe esmaecendo em Long. Minimizar (seta para baixo) e o voltar **não encerram**: a tela inteira encolhe descendo até o lugar da Barra do foco (cantos até `Shape/LG`, conteúdo esmaecendo na 1ª metade, cor final SurfaceContainerLowest), em Long · Emphasized, e a barra aparece nos últimos 30% (pedido do usuário, 09/11/2026). Encerrado (sem barra), só desce | `NexoPageMotion.focus` + `morphTarget: focusBarKey` |
| Splash → Login (Hero) e Tutorial | Esmaecimento longo | `NexoPageMotion.fadeLong` |
| Splash/Login → Início | Esmaecimento | `NexoPageMotion.fade` |
| Passos do Criar plano | Eixo X só no conteúdo (`distancePage`); o topo e o rodapé ficam | `StepSwitcher` |

- **Durações:** abrir em Medium e fechar ou voltar em Short (a transição inversa), com `Easing/Exit` na volta. O Hero da logo usa Long.
- **Feedbacks:** Dialog entra esmaecendo e crescendo de `scaleEnter` (Medium · Enter) e sai em Short · Exit; menus entram em Short · Enter e saem em Instant; BottomSheet sobe em Medium · Emphasized e desce em Short · Exit (`showNexoModal` para a saída mais curta).
- **Menu do toque longo** (§8.4): nasce no ponto tocado (`anchorAt(ponto)`, empurrado para dentro da tela perto das bordas) e cresce dali (`showNexoMenu(growFrom:)`), de `scaleEnter` a 1 com esmaecimento, em Short · Enter; sai em Instant · Exit. Pelo leitor de tela (sem toque), nasce no centro da linha. **Não vibra:** o `NexoTappable` com toque longo desliga o `enableFeedback` do `InkWell` (que vibraria no toque longo) e chama `Feedback.forTap` no toque simples. A vibração continua só ao concluir.
- **Saída e volta de item de lista** (§8.1, no `NexoCardList`): um filho com chave que some fecha a altura e esmaece nos primeiros 60% (Short · Exit), com os de baixo subindo; o que aparece (Desfazer, mudança de grupo ao pausar ou encerrar) abre na mesma posição e esmaece nos últimos 60% (Medium · Enter). Vários de uma vez saem juntos. Vale para tarefas (Tarefas, Hoje do Início, disciplina), disciplinas, planos e objetivos. Os avisos ainda não têm excluir nem limpar. Com "reduzir movimento", some e reaparece na hora.
  - Não feito: mandar o foco do leitor de tela para o item seguinte depois de excluir. O Flutter não tem uma forma direta de mover o foco do TalkBack; a Snackbar com "Desfazer" continua sendo o anúncio.
- **Reduzir movimento** (`MediaQuery.disableAnimations`): duração zero em tudo, inclusive na troca de aba.
- **Voltar preditivo do Android** (MVP, decisão do usuário de 08/11/2026, opção A): `android:enableOnBackInvokedCallback="true"` no manifesto. O gesto funciona, mas **sem prévia ao vivo**: durante o arrasto a tela não se mexe e, ao soltar, roda a transição inversa da tela. No Flutter 3.47 com go_router 18, a prévia ao vivo só existe nas páginas Material padrão (`PredictiveBackPageTransitionsBuilder`), e as transições do Nexo são personalizadas. **A prévia ao vivo nas transições personalizadas fica para depois do MVP.**
  - Casos com `PopScope` (sem prévia): criar ou editar com alterações abre "Descartar alterações?"; Criar plano nos passos 2 e 3 recua um passo; outra aba vai ao Início com fade through; no Início, o diálogo "Deseja sair do app?" continua (decisão do usuário).
- **Fora do MVP:** container transform (o cartão "crescendo" até o detalhe).

## Ícones: fontes do Lucide (decisão de 09/11/2026)

O pacote `lucide_icons_flutter` (4.0.x) traz 6 fontes variáveis (`LucideVariable-w100` a `w600`): **2,99 MB sem compressão e cerca de 1,40 MB comprimidos no APK**. O app usa 73 ícones de `lucide_icons.dart` em um único peso. Opções avaliadas:

1. **`flutter_lucide`** (1.70): uma fonte só, mas os nomes dos ícones mudam (snake_case) em todo o app.
2. **Copiar a fonte para o app**: registro manual da fonte e da licença ISC.
3. **Cópia local enxuta do pacote** (`app/packages/lucide_icons_flutter` via `dependency_overrides` por path, só com a fonte usada): cerca de −1,4 MB, sem mudar o código. Era a recomendação.

**Decisão do usuário: deixar como está.** Retomar se o tamanho do APK virar problema; a opção 3 é a de menor impacto no código.
