import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/local_date.dart';
import '../../auth/application/auth_providers.dart';
import '../../tasks/application/screen_now.dart';
import '../domain/plan.dart';
import '../domain/plan_day_result.dart';
import 'plan_today.dart';
import 'plans_providers.dart';

/// Grupos da lista de Planos, na ordem da tela (design de Planos 02):
/// Principal · Ativos · Pausados · Concluídos e encerrados (recolhido) ·
/// Arquivados (recolhido). Grupos vazios não aparecem.
enum PlanGroup {
  primary('Principal'),
  active('Ativos'),
  paused('Pausados'),
  ended('Concluídos e encerrados'),
  archived('Arquivados');

  const PlanGroup(this.label);

  final String label;

  /// Recolhidos ao abrir.
  bool get startsCollapsed => this == ended || this == archived;
}

/// Grupo pronto para a tela: os planos, em ordem alfabética.
typedef PlanListGroup = ({PlanGroup group, List<PlanSnapshot> plans});

/// Grupo de [plan] em [today] (encerrado pela regra única
/// [Plan.isFinished]).
PlanGroup planGroupOf(
  Plan plan, {
  String? primaryId,
  required LocalDate today,
}) {
  if (plan.status == PlanStatus.archived) return PlanGroup.archived;
  if (plan.isFinished(today)) return PlanGroup.ended;
  if (plan.id == primaryId) return PlanGroup.primary;
  if (plan.status == PlanStatus.paused) return PlanGroup.paused;
  return PlanGroup.active;
}

/// A lista de Planos por grupo. `null` enquanto carrega.
final planListProvider = Provider<List<PlanListGroup>?>((ref) {
  final plans = ref.watch(plansProvider);
  final profile = ref.watch(userProfileProvider);
  if (!plans.hasValue || !profile.hasValue) return null;
  final today = LocalDate.fromDateTime(ref.watch(screenNowProvider));
  final primaryId = profile.value?.primaryPlanId;
  final buckets = <PlanGroup, List<PlanSnapshot>>{};
  for (final plan in plans.value!) {
    final snapshot = ref.watch(planSnapshotProvider(plan.id));
    if (snapshot == null) return null;
    final group = planGroupOf(plan, primaryId: primaryId, today: today);
    (buckets[group] ??= []).add(snapshot);
  }
  return [
    for (final group in PlanGroup.values)
      if (buckets[group] case final list?)
        (
          group: group,
          plans: list
            ..sort(
              (a, b) => a.plan.name.toLowerCase().compareTo(
                b.plan.name.toLowerCase(),
              ),
            ),
        ),
  ];
});
