import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../application/home_view.dart';

/// Lista em cartão (Card/Default, Shape/LG, borda) com divisores
/// (OutlineVariant, recuo LG), como os blocos Hoje e Próximas entregas.
class HomeCardList extends StatelessWidget {
  const HomeCardList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    return NexoCard(
      padding: EdgeInsets.zero,
      radius: context.shape.lg,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: c.outlineVariant,
                ),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Título e texto acima dos primeiros passos (estados 02 e 03).
class HomeWelcome extends StatelessWidget {
  const HomeWelcome({super.key, required this.steps});

  final HomeFirstSteps steps;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final textTheme = Theme.of(context).textTheme;
    final (title, message) = steps.task
        ? (
            'Boa, primeira tarefa criada',
            'Agora crie um plano para o Início mostrar sua meta do dia.',
          )
        : (
            'Seu dia começa aqui',
            'Em 3 passos, o Início passa a mostrar o que fazer hoje e no '
                'que focar.',
          );
    return Padding(
      padding: EdgeInsets.only(top: context.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: textTheme.titleLarge!.copyWith(color: c.onSurface),
            ),
          ),
          SizedBox(height: context.spacing.xs),
          Text(
            message,
            style: textTheme.bodyMedium!.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Dica do estado 02: criar também pelo "+" da barra.
class HomeTip extends StatelessWidget {
  const HomeTip({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              LucideIcons.circlePlus,
              size: 16,
              color: c.iconSecondary,
            ),
          ),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Text(
              'Você também pode criar tarefas e planos a qualquer momento '
              'pelo + da barra.',
              style: Theme.of(context).textTheme.labelSmall!
                  .copyWith(color: c.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Marcador de 32 de uma etapa: feita (check), a próxima (número em
/// PrimaryContainer) ou depois (número em SurfaceContainer com a borda
/// `StepMarker/Border`, que no escuro separa o círculo do cartão).
class _StepMarker extends StatelessWidget {
  const _StepMarker({required this.number, required this.done, this.next});

  static const double size = 32;

  final int number;
  final bool done;
  final bool? next;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final upcoming = !done && !(next ?? false);
    final (Color background, Color content) = done
        ? (c.successContainer, c.onSuccessContainer)
        : (next ?? false)
        ? (c.primaryContainer, c.onPrimaryContainer)
        : (c.surfaceContainer, c.onSurfaceVariant);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: upcoming ? Border.all(color: c.stepMarkerBorder) : null,
        ),
        child: done
            ? Icon(LucideIcons.check, size: 16, color: content)
            : Text(
                '$number',
                style: context
                    .textStyle(NexoTextStyles.labelMediumEmphasis)
                    .copyWith(color: content),
              ),
      ),
    );
  }
}

/// Cartão "Primeiros passos" (estados 02 e 03, ainda sem plano): progresso
/// "k de 3" (Secondary), as 3 etapas tocáveis e UMA ação principal, a
/// próxima etapa.
class FirstStepsCard extends StatelessWidget {
  const FirstStepsCard({
    super.key,
    required this.steps,
    required this.onCreateTask,
    required this.onCreatePlan,
  });

  final HomeFirstSteps steps;
  final VoidCallback onCreateTask;
  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final nextIsTask = !steps.task;

    final items = [
      (
        title: 'Crie sua primeira tarefa',
        description: 'Com prazo, prioridade e disciplina',
        done: steps.task,
        onTap: onCreateTask,
      ),
      (
        title: 'Crie seu primeiro plano',
        description: 'Objetivo com período e meta diária',
        done: steps.plan,
        onTap: onCreatePlan,
      ),
      // Focar pede um plano: a etapa 3 só fica tocável com ele (linha do
      // estado 04).
      (
        title: 'Faça uma sessão de foco',
        description: 'O tempo estudado entra no plano',
        done: steps.session,
        onTap: null,
      ),
    ];
    final next = items.indexWhere((s) => !s.done);

    return NexoCard(
      padding: EdgeInsets.only(top: spacing.sm, bottom: spacing.lg),
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.lg,
              spacing.sm,
              spacing.lg,
              spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Primeiros passos',
                          style: textTheme.titleMedium!.copyWith(
                            color: c.onSurface,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '${steps.done} de 3',
                      style: textTheme.labelSmall!.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing.sm),
                NexoLinearProgress(
                  value: steps.done / 3,
                  semanticsLabel: 'Primeiros passos',
                  semanticsValue: '${steps.done} de 3',
                ),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _StepRow(
              number: i + 1,
              title: items[i].title,
              description: items[i].done ? 'Feito' : items[i].description,
              done: items[i].done,
              next: i == next,
              onTap: items[i].done ? null : items[i].onTap,
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(spacing.lg, spacing.sm, spacing.lg, 0),
            child: NexoButton.primary(
              label: nextIsTask
                  ? 'Criar minha primeira tarefa'
                  : 'Criar meu primeiro plano',
              leadingIcon: LucideIcons.plus,
              expand: true,
              onPressed: nextIsTask ? onCreateTask : onCreatePlan,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.description,
    required this.done,
    required this.next,
    required this.onTap,
  });

  final int number;
  final String title;
  final String description;
  final bool done;
  final bool next;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final state = done ? 'feito' : 'pendente';
    return Semantics(
      button: onTap != null,
      label: 'Passo $number de 3: $title, $state',
      onTap: onTap,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: context.sizes.target),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.md,
            ),
            child: Row(
              children: [
                _StepMarker(number: number, done: done, next: next),
                SizedBox(width: spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context
                            .textStyle(NexoTextStyles.labelMediumEmphasis)
                            .copyWith(
                              color: done ? c.onSurfaceVariant : c.onSurface,
                            ),
                      ),
                      SizedBox(height: spacing.xxs),
                      Text(
                        description,
                        style: textTheme.labelSmall!.copyWith(
                          color: done ? c.success : c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  SizedBox(width: spacing.md),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 20,
                    color: c.iconSecondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Primeiros passos" encolhido numa linha, abaixo do plano (estado 04):
/// aponta a etapa que falta e pode ser dispensado.
class FirstStepsLine extends StatelessWidget {
  const FirstStepsLine({
    super.key,
    required this.steps,
    required this.onDismiss,
  });

  final HomeFirstSteps steps;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final (number, description) = !steps.task
        ? (1, 'Falta sua primeira tarefa: crie pelo + da barra.')
        : (3, 'Falta sua primeira sessão de foco: toque em Focar.');
    return NexoCard(
      padding: EdgeInsets.fromLTRB(
        spacing.md,
        spacing.sm,
        spacing.xs,
        spacing.sm,
      ),
      child: Row(
        children: [
          _StepMarker(number: number, done: false, next: true),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Primeiros passos · ${steps.done} de 3',
                  style: context
                      .textStyle(NexoTextStyles.labelMediumEmphasis)
                      .copyWith(color: c.onSurface),
                ),
                SizedBox(height: spacing.xxs),
                Text(
                  description,
                  style: Theme.of(context).textTheme.labelSmall!
                      .copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
          NexoIconButton(
            icon: LucideIcons.x,
            tooltip: 'Dispensar primeiros passos',
            iconSize: 20,
            color: c.iconSecondary,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// Estado 01: skeletons com a forma de todo o conteúdo final, ocupando a
/// tela inteira (inclusive atrás da barra de vidro). Anuncia "Carregando o
/// Início"; estático com "reduzir movimento".
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final target = context.sizes.target;

    Widget row() => Row(
      children: [
        NexoSkeleton(width: 20, height: 20, radius: context.shape.xs),
        SizedBox(width: spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NexoSkeleton(height: 12),
              SizedBox(height: spacing.sm),
              const NexoSkeleton(width: 140, height: 10),
            ],
          ),
        ),
      ],
    );

    Widget list(double titleWidth) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NexoSkeleton(width: titleWidth, height: 16),
        SizedBox(height: spacing.md),
        NexoCard(
          radius: context.shape.lg,
          child: Column(
            children: [
              row(),
              SizedBox(height: spacing.lg),
              row(),
              SizedBox(height: spacing.lg),
              row(),
            ],
          ),
        ),
      ],
    );

    return NexoSkeletonScope(
      label: 'Carregando o Início',
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          spacing.lg,
          spacing.sm,
          spacing.lg,
          MediaQuery.paddingOf(context).bottom + spacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NexoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NexoSkeleton(width: 96, height: 12),
                  SizedBox(height: spacing.md),
                  const NexoSkeleton(width: 220, height: 20),
                  SizedBox(height: spacing.md),
                  const NexoSkeleton(height: 8),
                  SizedBox(height: spacing.md),
                  const NexoSkeleton(width: 120, height: 12),
                  SizedBox(height: spacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: NexoSkeleton(
                          height: target,
                          radius: context.shape.md,
                        ),
                      ),
                      SizedBox(width: spacing.md),
                      NexoSkeleton(
                        width: 110,
                        height: target,
                        radius: context.shape.md,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.xl),
            list(90),
            SizedBox(height: spacing.xl),
            list(150),
          ],
        ),
      ),
    );
  }
}
