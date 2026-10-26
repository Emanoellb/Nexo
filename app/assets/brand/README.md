# Marca do Nexo

Versão 1.0, de 21/10/2026. Fonte: `D:\Dev\Nexo\pen.dev\nexo.brand.pen`, seção "Pacote da logo".

O símbolo é o **x como ponto de encontro**: um traço reto passa por baixo de um traço curvo. É o "x" de *nexo* (do latim *nexus*, ligação), o ponto onde o objetivo e a ação do dia se encontram.

> **Pendente antes de publicar:** busca de anterioridade e registro da marca no INPI (`docs/legal/pendencias.md`, item D8).

## Cores

| Uso | Cor | Token |
|---|---|---|
| Símbolo em fundo claro | `#567792` | `Brand/Mark` (light) = `Colors/Semantic/Primary` da lib |
| Símbolo em fundo escuro | `#6E92AE` | `Brand/Mark` (dark) = `Primary/500` da lib |
| Nome em fundo claro | `#1D2127` | `Brand/OnSurface` (light) |
| Nome em fundo escuro | `#FAFAFB` | `Brand/OnSurface` (dark) |
| Monocromática | `#1D2127` ou `#FAFAFB` | `Brand/Ink` / `Brand/Paper` |

Tipografia do nome: Manrope 700, com espaçamento levemente negativo.

## Arquivos

| Pasta | Conteúdo |
|---|---|
| `logo/svg/` | Símbolo vetorial: claro, escuro, mono grafite, mono claro (viewBox 160, com respiro de 4%) |
| `logo/png/` | Símbolo, assinatura horizontal e nome integrado (`ne×o`), para fundo claro e escuro, a 4x |
| `logo/pdf/` | Assinatura horizontal e nome integrado em vetor (para impressão e apresentações) |
| `app-icon/ios/` | `AppIcon-1024.png`: sem transparência e sem cantos (o iOS aplica a máscara) |
| `app-icon/android/` | Camadas do ícone adaptativo a 432 px (108 dp a 4x): background, foreground e monochrome |
| `favicon/` | 16, 32 e 64 px |

## Regras de uso

- **Tamanho mínimo:** 16 px para o símbolo e 24 px de altura para a assinatura horizontal.
- **Área de proteção:** pelo menos 25% da largura do símbolo livre em volta.
- **Não faça:** girar, esticar, contornar, aplicar gradiente ou sombra, trocar a cor fora dos tokens, colocar o símbolo azul sobre fundo de contraste baixo.
- **Ícone de app:** o símbolo ocupa cerca de 51% do ícone iOS. No Android, o símbolo (184 px) fica dentro da zona segura circular de 66 dp.
- **Dark mode:** use as versões "escuro". Elas trocam o azul para `#6E92AE` e o nome para `#FAFAFB`.

## Flutter (referência para a implementação)

- Ícones: gere com `flutter_launcher_icons`, usando `app-icon/ios/AppIcon-1024.png` e as camadas de `app-icon/android/` (`adaptive_icon_background`, `adaptive_icon_foreground`, `adaptive_icon_monochrome`).
- Logo dentro do app: `flutter_svg` com os arquivos de `logo/svg/`, escolhendo claro ou escuro pelo `Theme.of(context).brightness`.
