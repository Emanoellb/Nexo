import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/nexo_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../application/auth_messages.dart';

/// Moldura das telas de entrada: superfície clara, rolagem e margens de
/// 16 px, com largura máxima para telas largas. Conteúdo alinhado ao topo.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.children,
    this.onBack,
    this.backEnabled = true,
    this.top,
    this.topHeight = 0,
    this.centered = false,
  });

  final List<Widget> children;

  /// Mostra a TopAppBar só com o voltar (Cadastro, Esqueci a senha, 03b).
  final VoidCallback? onBack;

  /// `false`: a barra fica, com o voltar desabilitado.
  final bool backEnabled;

  /// Fixo no topo, fora do bloco centralizado (logo do Login), com altura
  /// [topHeight].
  final Widget? top;
  final double topHeight;

  /// Centraliza [children] na altura livre abaixo de [top]; se não couber,
  /// rola. Só no Login (pedido do usuário em 27/10/2026, diverge do
  /// nexo.app.pen, alinhado ao topo).
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final padding = EdgeInsets.fromLTRB(
      spacing.lg,
      // Sem TopAppBar, 24 px abaixo da barra de status (inclusive a logo do
      // Login, pedido do usuário em 27/10/2026).
      onBack == null ? spacing.xl : spacing.lg,
      spacing.lg,
      spacing.xl,
    );
    final form = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    final topSlot = top == null
        ? const <Widget>[]
        : [
            SizedBox(height: topHeight, child: top),
            SizedBox(height: spacing.xl),
          ];
    final topExtent = top == null ? 0.0 : topHeight + spacing.xl;

    // Centralizado: o bloco recebe como altura mínima o espaço livre abaixo
    // do topo e fica no meio dele. Sem medida intrínseca, que erra a altura
    // dos campos de texto.
    final body = LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...topSlot,
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: centered
                    ? (viewport.maxHeight - padding.vertical - topExtent).clamp(
                        0.0,
                        double.infinity,
                      )
                    : 0,
              ),
              child: Align(
                alignment: centered ? Alignment.center : Alignment.topCenter,
                child: form,
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: context.nexoColors.surface,
      appBar: onBack == null
          ? null
          : NexoTopAppBar(onBack: onBack, backEnabled: backEnabled),
      body: SafeArea(top: onBack == null, child: body),
    );
  }
}

/// Título e subtítulo das telas de entrada.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: textTheme.headlineLarge!.copyWith(color: c.onSurface),
          ),
        ),
        SizedBox(height: context.spacing.sm),
        Text(
          subtitle,
          style: textTheme.bodyLarge!.copyWith(color: c.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Separador "ou" entre o botão principal e o Google.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    Widget line() => Expanded(child: Divider(color: c.outlineVariant));
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.md),
      child: Row(
        children: [
          line(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.lg),
            child: Text(
              'ou',
              style: Theme.of(context).textTheme.bodySmall!
                  .copyWith(color: c.onSurfaceVariant),
            ),
          ),
          line(),
        ],
      ),
    );
  }
}

/// "Ainda não tem conta? Criar conta" / "Já tem conta? Entrar".
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.question,
    required this.action,
    required this.onPressed,
  });

  final String question;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.spacing.xs,
      children: [
        Text(
          question,
          style: Theme.of(context).textTheme.bodyMedium!
              .copyWith(color: context.nexoColors.onSurfaceVariant),
        ),
        NexoButton.tertiary(label: action, onPressed: onPressed),
      ],
    );
  }
}

/// Texto de apoio centralizado abaixo de um botão desabilitado.
class AuthHint extends StatelessWidget {
  const AuthHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.spacing.md),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium!
            .copyWith(color: context.nexoColors.onSurfaceVariant),
      ),
    );
  }
}

/// Selo do envelope das telas 04 (Link enviado) e 05.
class MailBadge extends StatelessWidget {
  const MailBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    return Align(
      alignment: Alignment.centerLeft,
      child: ExcludeSemantics(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: c.primaryContainer,
            borderRadius: BorderRadius.circular(context.shape.lg),
          ),
          alignment: Alignment.center,
          child: Icon(LucideIcons.mailCheck, size: 32, color: c.iconDefault),
        ),
      ),
    );
  }
}

/// Aceite dos Termos e da Política (Cadastro e 03b), com os dois links.
class LegalConsentField extends StatelessWidget {
  const LegalConsentField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NexoCheckbox(
          value: value,
          onChanged: onChanged,
          labelText:
              'Li e aceito os Termos de Uso e estou ciente da Política de '
              'Privacidade',
        ),
        SizedBox(height: context.spacing.xs),
        // Quebra em duas linhas com fonte ampliada ou tela estreita.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            NexoButton.tertiary(label: 'Termos de Uso', onPressed: onOpenTerms),
            ExcludeSemantics(
              child: Text('·', style: TextStyle(color: c.onSurfaceVariant)),
            ),
            NexoButton.tertiary(
              label: 'Política de Privacidade',
              onPressed: onOpenPrivacy,
            ),
          ],
        ),
      ],
    );
  }
}

/// "Reenviar" com a contagem regressiva ("Reenviar em 0:45").
class ResendButton extends StatelessWidget {
  const ResendButton({
    super.key,
    required this.label,
    required this.secondsLeft,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final int secondsLeft;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final waiting = secondsLeft > 0;
    return Center(
      child: NexoButton.tertiary(
        label: waiting ? 'Reenviar em ${formatCountdown(secondsLeft)}' : label,
        loading: loading,
        onPressed: waiting ? null : onPressed,
      ),
    );
  }
}
