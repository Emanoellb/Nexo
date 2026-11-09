import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/nexo_theme.dart';
import '../buttons/nexo_icon_button.dart';

/// `Feedback/BottomSheet` da lib: painel modal sobre o Scrim, altura pelo
/// conteúdo (até 90% da tela), cantos `Shape/XL` em cima, Elevation/3, alça
/// de 32 × 4 (OutlineVariant) numa faixa de 24, com alvo de 48 que fecha o
/// painel (botão "Fechar" no leitor de tela, como a alça do M3), título
/// TitleMedium (cabeçalho) e o conteúdo. Sobe junto com o teclado. Fecha arrastando para baixo, pelo
/// voltar ou tocando no fundo. Entra em Motion/Duration/Medium + Enter;
/// sem movimento com "reduzir movimento".
///
/// Abre no navegador raiz: por cima da barra de abas (o Scrim cobre a
/// barra; dentro de uma aba, a barra de vidro ficaria por cima do painel).
Future<T?> showNexoBottomSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) => showNexoBottomSheetWith<T>(
  context,
  builder: (sheetContext) =>
      NexoBottomSheet(title: title, child: builder(sheetContext)),
);

/// Como [showNexoBottomSheet], mas [builder] monta o próprio
/// [NexoBottomSheet]: para o painel que troca de conteúdo e de título sem
/// empilhar outro (ex.: "Novo tópico" → "Nova disciplina", com voltar).
Future<T?> showNexoBottomSheetWith<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final c = context.nexoColors;
  final motion = context.motion;
  final reduce = MediaQuery.disableAnimationsOf(context);
  final radius = Radius.circular(context.shape.xl);
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    // Fundo, cantos e sombra (Elevation/3 da lib) vêm do NexoBottomSheet.
    backgroundColor: c.surfaceContainerLowest.withValues(alpha: 0),
    elevation: 0,
    barrierColor: c.scrim,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: radius),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    sheetAnimationStyle: AnimationStyle(
      duration: reduce ? Duration.zero : motion.medium,
      reverseDuration: reduce ? Duration.zero : motion.short,
      // Sobe em Medium · Emphasized; desce em Short · Exit.
      curve: motion.emphasized,
      reverseCurve: motion.exit.flipped,
    ),
    builder: builder,
  );
}

class NexoBottomSheet extends StatelessWidget {
  const NexoBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
  });

  /// Alça (lib: 32 × 4, numa faixa de 24).
  static const Size handle = Size(32, 4);
  static const double handleArea = 24;

  final String title;
  final Widget child;

  /// Seta de voltar antes do título: volta ao conteúdo anterior do mesmo
  /// painel (não fecha).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final target = context.sizes.target;
    void close() => Navigator.of(context).maybePop();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.shape.xl),
        ),
        boxShadow: context.elevation.level(3),
      ),
      child: Padding(
        // Sobe com o teclado.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A alça e o título num Stack: o alvo de 48 da alça cobre a
              // faixa de 24 e o começo do cabeçalho, sem mudar o layout.
              Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: handleArea,
                        child: Center(
                          child: Container(
                            width: handle.width,
                            height: handle.height,
                            decoration: BoxDecoration(
                              color: c.outlineVariant,
                              borderRadius: BorderRadius.circular(
                                context.shape.full,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          spacing.lg,
                          spacing.xs,
                          spacing.lg,
                          spacing.sm,
                        ),
                        child: Row(
                          children: [
                            if (onBack != null) ...[
                              NexoIconButton(
                                icon: LucideIcons.arrowLeft,
                                tooltip: 'Voltar',
                                color: c.iconDefault,
                                onPressed: onBack,
                              ),
                              SizedBox(width: spacing.xs),
                            ],
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .copyWith(color: c.onSurface),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: target,
                    child: Center(
                      child: Semantics(
                        button: true,
                        label: 'Fechar',
                        onTap: close,
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: close,
                          child: SizedBox.square(dimension: target),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
