import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Uma medalha do catálogo (`achievementsCatalog`, contrato §4: 9 medalhas,
/// decididas pelo usuário em 24/10/2026). No MVP o app usa este catálogo;
/// o do Firestore é o mesmo, carregado pelo console.
@immutable
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.order,
    required this.title,
    required this.criterion,
    required this.icon,
    required this.goal,
  });

  final String id;
  final int order;
  final String title;
  final String criterion;
  final IconData icon;

  /// Quanto o critério pede (1 plano, 7 dias seguidos, 10 tarefas...).
  final int goal;
}

/// O que conta para cada critério, calculado pelo app a partir dos dados.
@immutable
class AchievementInputs {
  const AchievementInputs({
    required this.plans,
    required this.focusSessions,
    required this.metDays,
    required this.longestStreak,
    required this.completedTasks,
    required this.finishedPlans,
    this.daysToFinishPlan,
  });

  final int plans;
  final int focusSessions;
  final int metDays;

  /// A maior sequência de dias cumpridos, entre todos os planos.
  final int longestStreak;
  final int completedTasks;

  /// Planos que chegaram ao fim do período.
  final int finishedPlans;

  /// Quantos dias faltam para o plano ativo mais perto do fim (`null` sem
  /// plano ativo).
  final int? daysToFinishPlan;
}

abstract final class NexoAchievements {
  static const catalog = <AchievementDef>[
    AchievementDef(
      id: 'primeiro-plano',
      order: 1,
      title: 'Primeiro plano',
      criterion: 'Crie seu primeiro plano de ação.',
      icon: LucideIcons.flag,
      goal: 1,
    ),
    AchievementDef(
      id: 'primeiro-foco',
      order: 2,
      title: 'Primeiro foco',
      criterion: 'Encerre sua primeira sessão de foco.',
      icon: LucideIcons.timer,
      goal: 1,
    ),
    AchievementDef(
      id: 'primeiro-dia',
      order: 3,
      title: 'Primeiro dia cumprido',
      criterion: 'Cumpra um dia de plano.',
      icon: LucideIcons.calendarCheck,
      goal: 1,
    ),
    AchievementDef(
      id: 'sete-dias',
      order: 4,
      title: '7 dias seguidos',
      criterion: 'Chegue a uma sequência de 7 dias cumpridos.',
      icon: LucideIcons.flame,
      goal: 7,
    ),
    AchievementDef(
      id: 'catorze-dias',
      order: 5,
      title: '14 dias seguidos',
      criterion: 'Chegue a uma sequência de 14 dias cumpridos.',
      icon: LucideIcons.flame,
      goal: 14,
    ),
    AchievementDef(
      id: 'vinte-um-dias',
      order: 6,
      title: '21 dias seguidos',
      criterion: 'Chegue a uma sequência de 21 dias cumpridos.',
      icon: LucideIcons.flame,
      goal: 21,
    ),
    AchievementDef(
      id: 'trinta-dias',
      order: 7,
      title: '30 dias seguidos',
      criterion: 'Chegue a uma sequência de 30 dias cumpridos.',
      icon: LucideIcons.zap,
      goal: 30,
    ),
    AchievementDef(
      id: 'dez-tarefas',
      order: 8,
      title: '10 tarefas concluídas',
      criterion: 'Conclua 10 tarefas.',
      icon: LucideIcons.listChecks,
      goal: 10,
    ),
    AchievementDef(
      id: 'plano-concluido',
      order: 9,
      title: 'Plano concluído',
      criterion: 'Chegue ao fim do período de um plano.',
      icon: LucideIcons.trophy,
      goal: 1,
    ),
  ];

  /// Quanto já foi feito para [def] (pode passar do [AchievementDef.goal]).
  static int progressOf(AchievementDef def, AchievementInputs i) =>
      switch (def.id) {
        'primeiro-plano' => i.plans,
        'primeiro-foco' => i.focusSessions,
        'primeiro-dia' => i.metDays,
        'sete-dias' ||
        'catorze-dias' ||
        'vinte-um-dias' ||
        'trinta-dias' => i.longestStreak,
        'dez-tarefas' => i.completedTasks,
        'plano-concluido' => i.finishedPlans,
        _ => 0,
      };

  static bool isMet(AchievementDef def, AchievementInputs i) =>
      progressOf(def, i) >= def.goal;

  /// "Faltam 6 tarefas.", "Faltam 3 dias seguidos." ou `null` quando não
  /// dá para contar (ex.: ainda sem plano).
  static String? missingText(AchievementDef def, AchievementInputs i) {
    final left = def.goal - progressOf(def, i);
    if (left <= 0) return null;
    switch (def.id) {
      case 'sete-dias' || 'catorze-dias' || 'vinte-um-dias' || 'trinta-dias':
        return left == 1
            ? 'Falta 1 dia seguido.'
            : 'Faltam $left dias seguidos.';
      case 'dez-tarefas':
        return left == 1 ? 'Falta 1 tarefa.' : 'Faltam $left tarefas.';
      case 'plano-concluido':
        final days = i.daysToFinishPlan;
        if (days == null) return null;
        return days <= 1
            ? 'Seu plano termina amanhã.'
            : 'Faltam $days dias para o fim do seu plano.';
      default:
        return null;
    }
  }
}
