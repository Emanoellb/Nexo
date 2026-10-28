import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../application/auth_messages.dart';
import '../application/forgot_password_controller.dart';
import 'widgets/auth_layout.dart';

/// Tela 04 Esqueci minha senha: formulário e "Confira seu e-mail" (mensagem
/// neutra, sem dizer se a conta existe). Os estados de erro seguem a spec
/// auth-redefinicao-senha.md §7 e reaproveitam os Alerts do Login.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail});

  /// E-mail já digitado no Login.
  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  late final _email = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _back() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.login);

  void _send() {
    FocusScope.of(context).unfocus();
    ref.read(forgotPasswordControllerProvider.notifier).send(_email.text);
  }

  Future<void> _resend() async {
    final sent = await ref
        .read(forgotPasswordControllerProvider.notifier)
        .resend();
    if (sent && mounted) {
      showNexoSnackbar(
        context,
        message: 'Link reenviado.',
        tone: NexoSnackbarTone.success,
      );
    }
  }

  Widget? _alert(ForgotPasswordState state, VoidCallback retry) =>
      switch (state.alert) {
        null => null,
        ForgotPasswordAlert.offline => NexoAlert(
          tone: NexoAlertTone.info,
          icon: LucideIcons.wifiOff,
          title: 'Você está sem conexão',
          message: 'Sem conexão com a internet. Verifique e tente de novo.',
          actionLabel: 'Tentar de novo',
          onAction: retry,
        ),
        ForgotPasswordAlert.tooManyRequests => NexoAlert(
          tone: NexoAlertTone.warning,
          title: 'Muitas tentativas',
          // "Enviar link" volta quando a contagem termina.
          message:
              'Por segurança, você poderá pedir o link de novo em '
              '${formatCountdown(state.lockedFor)}.',
        ),
        ForgotPasswordAlert.generic => const NexoAlert(
          tone: NexoAlertTone.error,
          message:
              'Não conseguimos enviar o link agora. Tente de novo em '
              'instantes.',
        ),
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordControllerProvider);
    final controller = ref.read(forgotPasswordControllerProvider.notifier);
    final spacing = context.spacing;
    final sentTo = state.sentTo;

    if (sentTo != null) {
      final alert = _alert(state, _resend);
      return AuthScaffold(
        onBack: _back,
        children: [
          SizedBox(height: spacing.lg),
          const MailBadge(),
          SizedBox(height: spacing.xl),
          AuthHeader(
            title: 'Confira seu e-mail',
            subtitle:
                'Se houver uma conta com $sentTo, você vai receber um link '
                'para criar uma nova senha. Não achou? Olhe a caixa de spam.',
          ),
          SizedBox(height: spacing.xl),
          if (alert != null) ...[alert, SizedBox(height: spacing.lg)],
          NexoButton.primary(
            label: 'Voltar para o login',
            expand: true,
            onPressed: () => context.go(AppRoutes.login),
          ),
          SizedBox(height: spacing.lg),
          ResendButton(
            label: 'Reenviar link',
            secondsLeft: state.resendIn,
            loading: state.sending,
            onPressed: _resend,
          ),
        ],
      );
    }

    final alert = _alert(state, _send);
    return AuthScaffold(
      onBack: _back,
      children: [
        const AuthHeader(
          title: 'Redefina sua senha',
          subtitle:
              'Informe o e-mail da sua conta. Enviaremos um link para você '
              'criar uma nova senha.',
        ),
        SizedBox(height: spacing.xl),
        if (alert != null) ...[alert, SizedBox(height: spacing.lg)],
        NexoTextField(
          label: 'E-mail',
          controller: _email,
          hintText: 'nome@email.com',
          errorText: state.emailError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          onChanged: (_) => controller.emailChanged(),
          onSubmitted: (_) => _send(),
        ),
        SizedBox(height: spacing.xl),
        NexoButton.primary(
          label: 'Enviar link',
          expand: true,
          loading: state.sending,
          // Bloqueado por 60 s depois de "Muitas tentativas" (spec §7).
          onPressed: state.lockedFor > 0 ? null : _send,
        ),
      ],
    );
  }
}
