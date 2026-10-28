import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/data/clock.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../application/auth_messages.dart';
import '../application/sign_up_controller.dart';
import 'widgets/auth_layout.dart';

/// Tela 03 Cadastro (nexo.app.pen, 4 estados): padrão com "Criar conta"
/// desabilitado, erros de campo, "Este e-mail já tem uma conta" e
/// carregando.
class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _controllers = {
    for (final field in SignUpField.values) field: TextEditingController(),
  };
  final _focus = {for (final field in SignUpField.values) field: FocusNode()};

  @override
  void initState() {
    super.initState();
    // Erro de campo só depois de sair dele.
    for (final MapEntry(key: field, value: node) in _focus.entries) {
      node.addListener(() {
        if (!node.hasFocus) {
          ref.read(signUpControllerProvider.notifier).blur(field);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _back() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.login);

  Widget? _alert(SignUpState state) => switch (state.alert) {
    null => null,
    SignUpAlert.emailInUse => NexoAlert(
      tone: NexoAlertTone.error,
      title: 'Este e-mail já tem uma conta',
      message: 'Entre com ele ou use outro e-mail para criar uma conta nova.',
      actionLabel: 'Entrar com este e-mail',
      onAction: () => context.go(
        AppRoutes.login,
        extra: _controllers[SignUpField.email]!.text.trim(),
      ),
    ),
    SignUpAlert.offline => const NexoAlert(
      tone: NexoAlertTone.info,
      icon: LucideIcons.wifiOff,
      title: 'Você está sem conexão',
      message:
          'Conecte-se à internet para criar sua conta. Seus dados digitados '
          'ficam aqui.',
    ),
    SignUpAlert.tooManyRequests => NexoAlert(
      tone: NexoAlertTone.warning,
      title: 'Muitas tentativas',
      // "Criar conta" volta quando a contagem termina.
      message:
          'Por segurança, você poderá tentar de novo em '
          '${formatCountdown(state.lockedFor)}.',
    ),
    SignUpAlert.generic => const NexoAlert(
      tone: NexoAlertTone.error,
      title: 'Não foi possível criar sua conta',
      message: 'Tente de novo em instantes.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signUpControllerProvider);
    final controller = ref.read(signUpControllerProvider.notifier);
    final spacing = context.spacing;
    final now = ref.read(clockProvider)();
    final alert = _alert(state);

    NexoTextField field(
      SignUpField key, {
      required String label,
      String? hint,
      String? helper,
      TextInputType? keyboard,
      Iterable<String>? autofill,
      bool obscurable = false,
      TextCapitalization capitalization = TextCapitalization.none,
    }) => NexoTextField(
      label: label,
      controller: _controllers[key],
      focusNode: _focus[key],
      hintText: hint,
      helperText: helper,
      errorText: controller.errorOf(key),
      keyboardType: keyboard,
      textInputAction: TextInputAction.next,
      autofillHints: autofill,
      obscurable: obscurable,
      textCapitalization: capitalization,
      autocorrect: key == SignUpField.name,
      enabled: !state.busy,
      onChanged: (value) => controller.change(key, value),
    );

    return AuthScaffold(
      onBack: _back,
      children: [
        const AuthHeader(
          title: 'Crie sua conta',
          subtitle:
              'Organize objetivos, planos e sessões de foco em um só '
              'lugar.',
        ),
        SizedBox(height: spacing.xl),
        if (alert != null) ...[alert, SizedBox(height: spacing.lg)],
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field(
                SignUpField.name,
                label: 'Nome',
                hint: 'Como quer ser chamado',
                autofill: const [AutofillHints.name],
                capitalization: TextCapitalization.words,
              ),
              SizedBox(height: spacing.lg),
              NexoDateField(
                label: 'Data de nascimento',
                controller: _controllers[SignUpField.birthDate]!,
                focusNode: _focus[SignUpField.birthDate],
                errorText: controller.errorOf(SignUpField.birthDate),
                firstDate: DateTime(1900),
                lastDate: now,
                initialPickerDate: DateTime(now.year - 18, now.month),
                enabled: !state.busy,
                textInputAction: TextInputAction.next,
                onChanged: (value) =>
                    controller.change(SignUpField.birthDate, value),
              ),
              SizedBox(height: spacing.lg),
              field(
                SignUpField.email,
                label: 'E-mail',
                hint: 'nome@email.com',
                keyboard: TextInputType.emailAddress,
                autofill: const [AutofillHints.email],
              ),
              SizedBox(height: spacing.lg),
              field(
                SignUpField.password,
                label: 'Senha',
                hint: 'Crie uma senha',
                helper: AuthMessages.passwordHelper,
                obscurable: true,
                autofill: const [AutofillHints.newPassword],
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.lg),
        LegalConsentField(
          value: state.accepted,
          onChanged: state.busy ? null : controller.setAccepted,
          onOpenTerms: () => context.push(AppRoutes.terms),
          onOpenPrivacy: () => context.push(AppRoutes.privacy),
        ),
        SizedBox(height: spacing.xl),
        NexoButton.primary(
          label: 'Criar conta',
          expand: true,
          loading: state.submitting,
          onPressed: controller.canSubmit
              ? () {
                  FocusScope.of(context).unfocus();
                  controller.submit();
                }
              : null,
        ),
        if (controller.hint case final hint?) AuthHint(hint),
        const OrDivider(),
        NexoGoogleButton(
          loading: state.googleLoading,
          onPressed: state.submitting ? null : controller.signInWithGoogle,
        ),
        SizedBox(height: spacing.xl),
        AuthFooterLink(
          question: 'Já tem conta?',
          action: 'Entrar',
          onPressed: state.busy ? null : () => context.go(AppRoutes.login),
        ),
      ],
    );
  }
}
