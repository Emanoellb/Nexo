import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../buttons/nexo_icon_button.dart';
import '../foundation/nexo_tappable.dart';

/// `Navigation/TabHeader` da lib (aprovado em 04/11/2026): topo das abas,
/// com o nome da aba à esquerda e, à direita, o sino das notificações e o
/// avatar do Perfil. 64 de altura, padding 8/4/8/16.
class NexoTabHeader extends StatelessWidget {
  const NexoTabHeader({
    super.key,
    required this.title,
    required this.unreadCount,
    required this.onNotifications,
    required this.initials,
    required this.onProfile,
    this.bellKey,
  });

  static const double height = 64;

  final String title;

  /// Avisos não lidos: com 1 ou mais, o sino ganha o ponto.
  final int unreadCount;
  final VoidCallback onNotifications;

  /// Iniciais do nome (o avatar não tem foto).
  final String initials;
  final VoidCallback onProfile;

  /// Para ancorar o painel de notificações embaixo do sino.
  final Key? bellKey;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final bellLabel = switch (unreadCount) {
      0 => 'Notificações',
      1 => 'Notificações, 1 não lida',
      _ => 'Notificações, $unreadCount não lidas',
    };

    return ColoredBox(
      color: c.surface,
      child: SafeArea(
        bottom: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: height),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.lg,
              spacing.sm,
              spacing.xs,
              spacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium!
                          .copyWith(color: c.onSurface),
                    ),
                  ),
                ),
                Stack(
                  key: bellKey,
                  clipBehavior: Clip.none,
                  children: [
                    NexoIconButton(
                      icon: LucideIcons.bell,
                      tooltip: bellLabel,
                      color: c.iconDefault,
                      onPressed: onNotifications,
                    ),
                    if (unreadCount > 0)
                      // Ponto Error de 8 px com borda Surface de 2 px, no canto
                      // do sino (ícone de 24 no centro do alvo de 48).
                      Positioned(
                        top: spacing.sm,
                        right: spacing.sm,
                        child: IgnorePointer(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: c.error,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.surface, width: 2),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                _Avatar(initials: initials, onTap: onProfile),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.onTap});

  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final radius = BorderRadius.circular(context.shape.full);
    return Semantics(
      button: true,
      label: 'Perfil',
      onTap: onTap,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox.square(
          dimension: context.sizes.target,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primaryContainer,
                borderRadius: radius,
              ),
              child: Text(
                initials,
                style: NexoTextStyles.labelMediumEmphasis.copyWith(
                  color: c.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Iniciais para o avatar: a primeira letra do primeiro e do último nome
/// ("Ana Souza" → "AS"; "Ana" → "A").
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '';
  final first = parts.first.characters.first;
  final last = parts.length > 1 ? parts.last.characters.first : '';
  return (first + last).toUpperCase();
}
