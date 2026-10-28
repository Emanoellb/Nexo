import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../application/auth_providers.dart';
import '../application/verify_email_controller.dart';
import 'widgets/auth_layout.dart';

/// Tela 05 Verifique seu e-mail (obrigatória só para e-mail e senha):
/// padrão e "Ainda não encontramos a confirmação".
class VerifyEmailPage extends ConsumerWidget {
  const VerifyEmailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verifyEmailControllerProvider);
    final controller = ref.read(verifyEmailControllerProvider.notifier);
    final email = ref.watch(authStateProvider).value?.email ?? '';
    final spacing = context.spacing;
    final busy = state.checking || state.resending;

    Future<void> resend() async {
      final sent = await controller.resend();
      if (sent && context.mounted) {
        showNexoSnackbar(
          context,
          message: 'E-mail reenviado.',
          tone: NexoSnackbarTone.success,
        );
      }
    }

    Future<void> useAnotherEmail() async {
      await controller.useAnotherEmail();
      if (context.mounted) context.go(AppRoutes.signUp);
    }

    final alert = switch (state.alert) {
      null => null,
      VerifyEmailAlert.notConfirmedYet => const NexoAlert(
        tone: NexoAlertTone.warning,
        title: 'Ainda não encontramos a confirmação',
        message:
            'Abra o link que enviamos. Pode levar alguns minutos para '
            'chegar.',
      ),
      VerifyEmailAlert.offline => const NexoAlert(
        tone: NexoAlertTone.info,
        icon: LucideIcons.wifiOff,
        title: 'Você está sem conexão',
        message: 'Sem conexão com a internet. Verifique e tente de novo.',
      ),
      VerifyEmailAlert.generic => const NexoAlert(
        tone: NexoAlertTone.error,
        message: 'Não conseguimos conferir agora. Tente de novo em instantes.',
      ),
    };

    return AuthScaffold(
      children: [
        SizedBox(height: spacing.xxl),
        const MailBadge(),
        SizedBox(height: spacing.xl),
        AuthHeader(
          title: 'Confirme seu e-mail',
          subtitle:
              'Enviamos um link para $email. Toque nele para ativar sua conta '
              'e depois volte aqui.',
        ),
        SizedBox(height: spacing.xl),
        if (alert != null) ...[alert, SizedBox(height: spacing.lg)],
        NexoButton.primary(
          label: 'Já confirmei',
          expand: true,
          loading: state.checking,
          onPressed: state.resending ? null : controller.confirm,
        ),
        SizedBox(height: spacing.lg),
        ResendButton(
          label: 'Reenviar e-mail',
          secondsLeft: state.resendIn,
          loading: state.resending,
          onPressed: state.checking ? null : resend,
        ),
        SizedBox(height: spacing.sm),
        Center(
          child: NexoButton.tertiary(
            label: 'Usar outro e-mail',
            contentColor: context.nexoColors.onSurfaceVariant,
            onPressed: busy ? null : useAnotherEmail,
          ),
        ),
      ],
    );
  }
}
