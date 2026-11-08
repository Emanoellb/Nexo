import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/deferred_deletion.dart';
import '../domain/plan.dart';
import 'plans_providers.dart';

/// Chave da exclusão adiada de um tópico: `planId/topicId`.
String topicDeletionKey(String planId, String topicId) => '$planId/$topicId';

/// Tópicos com exclusão pendente (somem na hora; o definitivo só quando a
/// Snackbar com "Desfazer" some). As sessões ficam "sem tópico".
final pendingTopicDeletionsProvider =
    NotifierProvider<PendingDeletions, Set<String>>(PendingDeletions.new);

final topicDeletionProvider = Provider<DeferredDeletion>(
  (ref) => DeferredDeletion(ref, pendingTopicDeletionsProvider, (key) {
    final i = key.indexOf('/');
    return ref
        .read(plansRepositoryProvider)
        .deleteTopic(key.substring(0, i), key.substring(i + 1));
  }),
);

/// Os tópicos do plano sem os de exclusão pendente.
final visibleTopicsProvider =
    Provider.family<AsyncValue<List<PlanTopic>>, String>((ref, planId) {
      final pending = ref.watch(pendingTopicDeletionsProvider);
      return ref
          .watch(planTopicsProvider(planId))
          .whenData(
            (topics) => [
              for (final t in topics)
                if (!pending.contains(topicDeletionKey(planId, t.id))) t,
            ],
          );
    });
