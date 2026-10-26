# CLAUDE.md · Nexo

**A fonte de verdade é o [`AGENTS.md`](AGENTS.md).** Leia-o inteiro antes de qualquer tarefa. Este arquivo só complementa com o que é específico do Claude Code. Se os dois se contradisserem, não escolha: aponte o conflito e pergunte ao usuário.

## Documentação

- Fica em `app/docs/` (backend, frontend, legal) e `app/assets/brand/README.md`. **Não existem `.docs/` nem `Docs/` neste projeto.**
- Comece pela doc e depois vá ao código. Se divergirem, reporte com evidência.

## Pencil (pen.dev) via MCP

- Os `.pen` em `pen.dev/` são lidos e escritos **só** pelas ferramentas `mcp__pencil__*`, nunca com Read/Grep/Edit.
- **O Pencil grava no arquivo ATIVO do editor, não no `filePath` passado.** Antes de gravar, chame `get_app_state` e confirme qual arquivo está aberto. Se for outro, peça ao usuário para trocar.
- O `nexo.app.pen` importa a `nexo.lib.pen`: os ids da lib aparecem com prefixo `d:` e dá para ler a lib pelo app. Depois de mudar a lib:
  1. o usuário salva a lib (Ctrl+S);
  2. fecha e reabra o `nexo.app.pen`, para o app carregar a versão nova.
- Peça ao usuário para salvar o arquivo (Ctrl+S) ao fim de cada bloco de edição: o agente não consegue salvar.
- Textos padrão de componentes (ex.: "Detalhes da tarefa", "Use um título objetivo.") podem aparecer em instâncias. Confira com `resolveInstances: true` se estão ocultos (`enabled: false`).
- Particularidades já vistas:
  - `Move()` perde overrides de instância;
  - `ctx.problems`/`ctx.bounds` erram em linhas com padding em `$variável`; confie no screenshot;
  - nomes de glifos Lucide inválidos viram um "?";
  - `Replace()` dentro de componentes mestres pode falhar: use `Insert` + `Delete`.
- Siga a skill `pencil-dev-skill:pencil-design` em qualquer trabalho de design.

## Design System

Regras completas no `AGENTS.md` §6 e no mapeamento `app/docs/frontend/tokens-flutter.md`. Resumo para ajustes visuais (skill `ajuste-visual-design-system`):

- **Tokens:** só `Colors/Semantic/*` (Flutter: `colorScheme` / `context.nexoColors`), `context.spacing`, `context.shape`, `context.elevation`, `context.motion` e os estilos de texto do tema (Manrope). Zero hex ou primitiva em widget.
- **Componentes base:** `app/lib/core/ui/` (exportados em `ui.dart`). Reutilize antes de criar.
- **Tema:** só claro, com dark previsto pela troca dos papéis semânticos.
- **Decisões travadas:** Snackbar clara embaixo; superfícies claras; criação no topo; Secondary só para progresso e conquistas; alvo ≥ 48 px.

## Como trabalhar aqui

- **Antes de configurar Firebase, rodar automação, instalar algo ou implementar funcionalidade nova:** use a skill `explicar-antes-de-agir` (o quê, por quê, efeito).
- **Ao fim de implementação ou correção:** use a skill `relatorio-validacao`, com o status separado por tipo.
- **Bug em Flutter:** use a skill `bugfix-escopo-estrito` (Diagnóstico, Plano de ação, Código Corrigido, Validação, Justificativa).
- **Testes:** os comandos estão no `AGENTS.md` §8. Fora disso, pergunte antes de criar uma suíte nova.
- **Firebase Emulator:** só uma vez antes de cada deploy das regras; depois, encerre o processo da porta 8080. Teste de uso é em aparelho físico.
- **SHA de release:** ao ver sinais de publicação (keystore, `key.properties`, `signingConfig` de release, Play Console), avise o usuário antes de seguir.

## Sessões paralelas

O trabalho do Nexo roda em várias sessões do Claude Code: design system, prototipação, Flutter, Firebase, regras do Firestore, dados e legal, logo.

- Uma sessão só edita o que é dela.
- Dois escritores nunca no mesmo `.pen` ao mesmo tempo, por causa do arquivo ativo do Pencil.
- Pedidos para uma área pausada vão para as listas de pendências (`firebase-setup.md` §11, `firestore-rules.md` §7), não para a sessão pausada.
