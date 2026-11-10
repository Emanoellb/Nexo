import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/brand/nexo_animated_symbol.dart';
import '../../../core/ui/ui.dart';
import '../application/auth_messages.dart';
import '../application/login_controller.dart';
import 'widgets/auth_layout.dart';

/// Tela 02 Login (nexo.app.pen, 6 estados): padrão, carregando, erros de
/// campo, "E-mail ou senha incorretos", "Você está sem conexão" e "Muitas
/// tentativas".
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.initialEmail});

  /// E-mail já digitado em outra tela ("Entrar com este e-mail").
  final String? initialEmail;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();

  @override
  void didUpdateWidget(LoginPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // O Login pode ser reaproveitado pelo roteador (ex.: volta do Cadastro
    // com "Entrar com este e-mail"): o e-mail novo substitui o digitado.
    final email = widget.initialEmail;
    if (email != null && email != oldWidget.initialEmail) {
      _email.text = email;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    ref
        .read(loginControllerProvider.notifier)
        .submit(email: _email.text, password: _password.text);
  }

  void _openForgotPassword() =>
      context.push(AppRoutes.forgotPassword, extra: _email.text.trim());

  Widget? _alert(LoginState state) => switch (state.alert) {
    null => null,
    LoginAlert.invalidCredential => const NexoAlert(
      tone: NexoAlertTone.error,
      title: 'E-mail ou senha incorretos',
      message: 'Confira os dados e tente de novo, ou redefina sua senha.',
    ),
    LoginAlert.offline => const NexoAlert(
      tone: NexoAlertTone.info,
      icon: LucideIcons.wifiOff,
      title: 'Você está sem conexão',
      message:
          'Conecte-se à internet para entrar. Seus dados digitados ficam '
          'aqui.',
    ),
    LoginAlert.tooManyRequests => NexoAlert(
      tone: NexoAlertTone.warning,
      title: 'Muitas tentativas',
      // O Entrar volta quando a contagem termina.
      message:
          'Por segurança, você poderá tentar de novo em '
          '${formatCountdown(state.lockedFor)}. Se preferir, redefina sua '
          'senha.',
      actionLabel: 'Redefinir senha',
      onAction: _openForgotPassword,
    ),
    LoginAlert.generic => const NexoAlert(
      tone: NexoAlertTone.error,
      title: 'Não foi possível entrar',
      message: 'Tente de novo em instantes.',
    ),
    LoginAlert.underage => const NexoAlert(
      tone: NexoAlertTone.warning,
      title: 'Conta não criada',
      message: AuthMessages.underage,
    ),
    // O Cadastro criou a conta, mas não gravou o perfil e a desfez.
    LoginAlert.signUpFailed => const NexoAlert(
      tone: NexoAlertTone.error,
      title: 'Não foi possível criar sua conta',
      message: 'Confira sua conexão e faça o cadastro de novo.',
    ),
  };

  @override
  void initState() {
    super.initState();
    // Aviso que chegou antes de o Login abrir (ex.: a 03b apagou a conta).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showNotice(ref.read(entryNoticeProvider));
    });
  }

  /// Avisos de outra tela viram alerta que some em 5 s (decisão de
  /// 27/10/2026).
  void _showNotice(EntryNoticeKind? notice) {
    if (notice == null) return;
    ref.read(entryNoticeProvider.notifier).clear();
    if (notice == EntryNoticeKind.accountDeleted) {
      // Perfil 10: o Login com a Snackbar.
      showNexoSnackbar(
        context,
        message: 'Conta excluída.',
        tone: NexoSnackbarTone.success,
      );
      return;
    }
    ref.read(loginControllerProvider.notifier).showEntryNotice(notice);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final controller = ref.read(loginControllerProvider.notifier);
    final spacing = context.spacing;
    final alert = _alert(state);
    // Aviso que chega com o Login já aberto.
    ref.listen(entryNoticeProvider, (_, notice) => _showNotice(notice));

    return AuthScaffold(
      // Logo fixa no topo; o formulário fica centralizado abaixo dela.
      // O símbolo que "voa" da splash pousa no "x" do nome.
      top: const Align(
        alignment: Alignment.centerLeft,
        child: NexoWordmark(height: 24, heroTag: nexoLogoHeroTag),
      ),
      topHeight: 24,
      centered: true,
      children: [
        const AuthHeader(
          title: 'Entre na sua conta',
          subtitle: 'Continue de onde parou nos seus planos.',
        ),
        SizedBox(height: spacing.xl),
        if (alert != null) ...[alert, SizedBox(height: spacing.lg)],
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NexoTextField(
                label: 'E-mail',
                controller: _email,
                hintText: 'nome@email.com',
                errorText: state.emailError,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                onChanged: (_) => controller.emailChanged(),
              ),
              SizedBox(height: spacing.lg),
              NexoTextField(
                label: 'Senha',
                controller: _password,
                hintText: 'Sua senha',
                errorText: state.passwordError,
                obscurable: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) => controller.passwordChanged(),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: NexoButton.tertiary(
            label: 'Esqueci minha senha',
            onPressed: _openForgotPassword,
          ),
        ),
        SizedBox(height: spacing.lg),
        NexoButton.primary(
          label: 'Entrar',
          expand: true,
          loading: state.submitting,
          onPressed: state.locked || state.googleLoading ? null : _submit,
        ),
        const OrDivider(),
        NexoGoogleButton(
          loading: state.googleLoading,
          onPressed: state.submitting ? null : controller.signInWithGoogle,
        ),
        SizedBox(height: spacing.xl),
        AuthFooterLink(
          question: 'Ainda não tem conta?',
          action: 'Criar conta',
          onPressed: state.busy ? null : () => context.push(AppRoutes.signUp),
        ),
      ],
    );
  }
}
