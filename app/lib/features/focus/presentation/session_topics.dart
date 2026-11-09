import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../plans/application/plans_providers.dart';
import '../../plans/application/topic_actions.dart';
import '../../plans/domain/plan.dart';
import '../../plans/presentation/topic_sheet.dart';
import '../domain/focus_session.dart';

/// Tópicos de uma sessão (Foco, Encerrar, Registrar horas, Editar sessão):
/// um `Chip/Input` por tópico (X tira) e o `Chip/Assist` "+ Adicionar
/// tópico", até 3. Adicionar abre o menu com os tópicos do plano e "Novo
/// tópico…" (cria no plano).
class SessionTopicsField extends ConsumerWidget {
  const SessionTopicsField({
    super.key,
    required this.planId,
    required this.topicIds,
    required this.onChanged,
    this.center = false,
    this.helper,
  });

  final String planId;
  final List<String> topicIds;
  final ValueChanged<List<String>> onChanged;

  /// Centralizado (tela do Foco) ou alinhado ao começo (formulários).
  final bool center;

  /// "Opcional · até 3. As horas são divididas igualmente entre eles."
  final String? helper;

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    Rect anchor,
    List<PlanTopic> topics,
  ) async {
    final free = [
      for (final t in topics)
        if (!topicIds.contains(t.id)) t,
    ];
    final chosen = await showNexoMenu(
      context,
      anchor: anchor,
      label: 'Adicionar tópico',
      alignEnd: false,
      items: [
        for (final t in free) NexoMenuItem(label: t.name),
        const NexoMenuItem(label: 'Novo tópico…', icon: LucideIcons.plus),
      ],
    );
    if (chosen == null || !context.mounted) return;
    if (chosen < free.length) {
      onChanged([...topicIds, free[chosen].id]);
      return;
    }
    final result = await showTopicSheet(context);
    if (result == null || result.delete) return;
    final topic = await ref
        .read(plansRepositoryProvider)
        .addTopic(planId, result.name, subjectId: result.subjectId);
    onChanged([...topicIds, topic.id]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final topics =
        ref.watch(visibleTopicsProvider(planId)).value ?? const <PlanTopic>[];
    final names = {for (final t in topics) t.id: t.name};
    final full = topicIds.length >= FocusSession.maxTopics;
    return Column(
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: center ? WrapAlignment.center : WrapAlignment.start,
          spacing: spacing.sm,
          children: [
            for (final id in topicIds)
              NexoInputChip(
                key: ValueKey(id),
                label: names[id] ?? 'sem tópico',
                removeLabel: 'Tirar o tópico ${names[id] ?? ''}',
                onRemove: () => onChanged([...topicIds]..remove(id)),
              ),
            if (!full)
              Builder(
                builder: (chipContext) => NexoAssistChip(
                  label: 'Adicionar tópico',
                  icon: LucideIcons.plus,
                  onPressed: () {
                    final box = chipContext.findRenderObject()! as RenderBox;
                    _add(
                      context,
                      ref,
                      box.localToGlobal(Offset.zero) & box.size,
                      topics,
                    );
                  },
                ),
              ),
          ],
        ),
        if (helper != null) ...[
          SizedBox(height: spacing.xs),
          Text(
            full ? 'Máximo de 3 tópicos.' : helper!,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.bodySmall!
                .copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
