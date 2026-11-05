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
| `Glass/Blur` | `context.glass.blur` (24). As cores `Colors/Semantic/Glass/*` ficam em `context.nexoColors.glass*`; as de repouso (`Glass/Rest/*`) em `glassRestFill`, `glassRestSheen`, `glassRestEdge` |
| `Colors/Semantic/Unread` (novo, 04/11/2026) | `context.nexoColors.unread`: fundo da linha de aviso não lido. Claro `#F7F8F9` (igual ao antigo SurfaceContainerLow), escuro `#30353D` (mais claro que o cartão `#262A31`) |
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

## Decisão de componente que afeta o tema

Na lib, o rótulo do campo fica **acima** do campo (LabelMedium) e o valor usa BodyMedium (14). Não é o rótulo flutuante do Material. O `InputDecorationTheme` e o `TextField` do Nexo (fase 3) seguem a lib.
