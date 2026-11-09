import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../buttons/nexo_icon_button.dart';

/// `Navigation/TopAppBar/Small` da lib: 56 px, título alinhado à esquerda
/// (TitleMedium), voltar e ações em alvos de 48 px.
///
/// Respeita a área da barra de status (o Scaffold reserva a altura dela).
class NexoTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NexoTopAppBar({
    super.key,
    this.title,
    this.onBack,
    this.backEnabled = true,
    this.closeIcon = false,
    this.minimizeIcon = false,
    this.actions = const [],
  });

  /// Sem título, a barra mostra só o voltar (ex.: Esqueci minha senha).
  final String? title;

  /// `null` esconde o botão de voltar.
  final VoidCallback? onBack;

  /// `false` mostra o voltar desabilitado (ex.: enquanto a tela grava), sem
  /// tirar a barra e sem o layout pular.
  final bool backEnabled;

  /// X ("Fechar") no lugar da seta: telas de criar em tela cheia (ex.:
  /// Nova tarefa).
  final bool closeIcon;

  /// Seta para baixo ("Minimizar"): o Foco, que desce e continua.
  final bool minimizeIcon;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final brightness = Theme.of(context).brightness;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Material(
        color: c.surface,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: preferredSize.height,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.xs),
              child: Row(
                children: [
                  if (onBack != null)
                    NexoIconButton(
                      icon: minimizeIcon
                          ? LucideIcons.chevronDown
                          : closeIcon
                          ? LucideIcons.x
                          : LucideIcons.arrowLeft,
                      tooltip: minimizeIcon
                          ? 'Minimizar'
                          : closeIcon
                          ? 'Fechar'
                          : 'Voltar',
                      color: c.iconDefault,
                      onPressed: backEnabled ? onBack : null,
                    ),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: title == null
                        ? const SizedBox.shrink()
                        : Semantics(
                            header: true,
                            child: Text(
                              title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium!
                                  .copyWith(color: c.onSurface),
                            ),
                          ),
                  ),
                  ...actions,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
