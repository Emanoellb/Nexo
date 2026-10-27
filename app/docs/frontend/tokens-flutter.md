# Tokens do Nexo → Flutter

Fonte: variáveis de `pen.dev/nexo.lib.pen` (fora do repositório), lidas em 21/10/2026 pelo MCP do Pencil. O código fica em `app/lib/core/theme/`.

## Regras

1. **Widgets nunca usam cor literal nem primitiva.** As cores vêm de `Theme.of(context).colorScheme` (papéis do Material 3) ou de `context.nexoColors` (papéis do Nexo que o `ColorScheme` não tem).
2. **Os valores ficam num lugar só.** Cores em `nexo_colors.dart`, com os valores copiados da lib. Espaçamento, forma, sombra e movimento em `nexo_dimensions.dart`. Texto em `nexo_typography.dart`.
3. **Fonte da verdade, regra temporária [D] (26/10/2026):** com o Pencil indisponível, tokens e componentes novos ou ajustados nascem no Flutter (`app/lib/core/`). Cada mudança é anotada em [`sincronizar-lib.md`](sincronizar-lib.md). Em 28/10/2026, essas mudanças vão para o `nexo.lib.pen`. Fora isso, vale a regra de sempre: mudou um token na lib, atualize aqui.
4. **Dark mode (futuro):** criar `NexoColors.dark` e `NexoElevation.dark` com os mesmos campos e passar para `NexoTheme.build(brightness: Brightness.dark, ...)`. Nenhum widget muda, porque todos leem os papéis semânticos.

**Exceção à regra 1 (26/10/2026):** a splash nativa do Android (`android/app/src/main/res/values/colors.xml`) precisa de cor em hex, porque o XML do Android não lê os tokens do Flutter.
- `nexo_splash_background` = `Surface` (`#FAFAFB`);
- `nexo_splash_symbol` = `Primary` (`#567792`).

Se esses tokens mudarem, atualize também esse arquivo.

## Acesso no código

| Token da lib | Flutter |
|---|---|
| `Colors/Semantic/*` (papéis do M3) | `Theme.of(context).colorScheme.<papel>` |
| `Colors/Semantic/*` (todos, inclusive Success, Warning, Info, Card, Glass, Icon, Control, Disabled, Hover, Pressed, Focus, Selected) | `context.nexoColors.<campo>` |
| `Typography/*` | `Theme.of(context).textTheme.<slot>` ou `NexoTextStyles.<papel>` |
| `Spacing/*` | `context.spacing.xs … xxxxl` |
| `Shape/*` | `context.shape.xs … full` |
| `Elevation/0..5` | `context.elevation.level(n)` (lista de `BoxShadow`) |
| `Motion/*` | `context.motion.short`, `.standard` (`Cubic`), `.distanceSmall`… |
| `Glass/Blur` | `context.glass.blur` (24). As cores `Colors/Semantic/Glass/*` ficam em `context.nexoColors.glass*` |
| `typeface` (Manrope) | `nexoFontFamily`, empacotada em `assets/fonts/` (SIL OFL 1.1) |

## ColorScheme (Material 3)

| Campo do ColorScheme | Token da lib | Observação |
|---|---|---|
| primary / onPrimary / primaryContainer / onPrimaryContainer | Primary / OnPrimary / PrimaryContainer / OnPrimaryContainer | |
| secondary / onSecondary / secondaryContainer / onSecondaryContainer | Secondary / … | |
| tertiary / onTertiary / tertiaryContainer / onTertiaryContainer | **alias de Secondary** | A lib não tem Tertiary |
| error / onError / errorContainer / onErrorContainer | Error / … | |
| surface / onSurface / onSurfaceVariant | Surface / OnSurface / OnSurfaceVariant | |
| surfaceDim | SurfaceDim | Mesmo valor de SurfaceContainer (achado da auditoria) |
| surfaceBright | **alias de Surface** | |
| surfaceContainerLowest … High | SurfaceContainerLowest … High | |
| surfaceContainerHighest | **alias de SurfaceContainerHigh** | |
| outline / outlineVariant | Outline / OutlineVariant | Outline/Surface = 2,02:1. Contorno de campo usa `Control/Border` |
| shadow | OnSurface | Cor-base das sombras da lib (Neutral/900) |
| scrim | Scrim | |
| inverseSurface / onInverseSurface | OnSurface / Surface | Igual ao botão Apple da lib |
| inversePrimary | **alias de PrimaryContainer** | Sem token na lib |
| surfaceTint | transparente | O Nexo usa sombra, não tinta de elevação |

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
