import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';

/// Quem oferece o Nexo (o mesmo nome dos Termos de Uso, §1).
const nexoPublisher = 'Emanoel Barbosa';

/// Sobre o Nexo (decisão do usuário, 10/11/2026): o símbolo, o nome, a
/// versão e "Oferecido por"; embaixo, "Ver licenças e componentes" abre a
/// tela de licenças do Flutter (os avisos que as licenças de código aberto
/// pedem para acompanhar o app).
Future<void> showAboutNexoSheet(BuildContext context, {String? version}) =>
    showNexoBottomSheet<void>(
      context,
      title: 'Sobre o Nexo',
      builder: (sheetContext) {
        final c = sheetContext.nexoColors;
        final spacing = sheetContext.spacing;
        final textTheme = Theme.of(sheetContext).textTheme;
        final muted = textTheme.bodyMedium!.copyWith(color: c.onSurfaceVariant);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: NexoLogoSymbol(size: 48, semanticLabel: '')),
              SizedBox(height: spacing.md),
              Text(
                'Nexo',
                textAlign: TextAlign.center,
                style: textTheme.titleLarge!.copyWith(color: c.onSurface),
              ),
              if (version != null) ...[
                SizedBox(height: spacing.xs),
                Text(
                  'Versão $version',
                  textAlign: TextAlign.center,
                  style: muted,
                ),
              ],
              SizedBox(height: spacing.xs),
              Text(
                'Oferecido por $nexoPublisher',
                textAlign: TextAlign.center,
                style: muted,
              ),
              SizedBox(height: spacing.xl),
              NexoButton.secondary(
                label: 'Ver licenças e componentes',
                leadingIcon: LucideIcons.fileText,
                expand: true,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  showLicensePage(
                    context: context,
                    applicationName: 'Nexo',
                    applicationVersion: version,
                    applicationLegalese: 'Oferecido por $nexoPublisher',
                  );
                },
              ),
              SizedBox(height: spacing.lg),
            ],
          ),
        );
      },
    );
