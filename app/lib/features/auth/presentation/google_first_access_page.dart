import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/data/clock.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../application/auth_providers.dart';
import '../application/google_first_access_controller.dart';
import 'widgets/auth_layout.dart';

/// Tela 03b Primeiro acesso com Google: data de nascimento (16+) e aceite.
class GoogleFirstAccessPage extends ConsumerStatefulWidget {
  const GoogleFirstAccessPage({super.key});

  @override
  ConsumerState<GoogleFirstAccessPage> createState() =>
      _GoogleFirstAccessPageState();
}

class _GoogleFirstAccessPageState extends ConsumerState<GoogleFirstAccessPage> {
  late final _name = TextEditingController(
    text: ref.read(googleFirstAccessControllerProvider).name,
  );
  final _birthDate = TextEditingController();
  final _nameFocus = FocusNode();
  final _birthDateFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    void blurOn(FocusNode node, GoogleFirstAccessField field) =>
        node.addListener(() {
          if (!node.hasFocus) {
            ref.read(googleFirstAccessControllerProvider.notifier).blur(field);
          }
        });
    blurOn(_nameFocus, GoogleFirstAccessField.name);
    blurOn(_birthDateFocus, GoogleFirstAccessField.birthDate);
  }

  @override
  void dispose() {
    _name.dispose();
    _birthDate.dispose();
    _nameFocus.dispose();
    _birthDateFocus.dispose();
    super.dispose();
  }

  Widget? _alert(GoogleFirstAccessAlert? alert) => switch (alert) {
    null => null,
    GoogleFirstAccessAlert.offline => const NexoAlert(
      tone: NexoAlertTone.info,
      icon: LucideIcons.wifiOff,
      title: 'Você está sem conexão',
      message:
          'Conecte-se à internet para continuar. Seus dados digitados ficam '
          'aqui.',
    ),
    GoogleFirstAccessAlert.generic => const NexoAlert(
      tone: NexoAlertTone.error,
      title: 'Não foi possível continuar',
      message: 'Tente de novo em instantes.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(googleFirstAccessControllerProvider);
    final controller = ref.read(googleFirstAccessControllerProvider.notifier);
    final email = ref.watch(authStateProvider).value?.email ?? '';
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final now = ref.read(clockProvider)();
    final busy = state.submitting || state.leaving;
    final alert = _alert(state.alert);

    // Voltar (seta ou botão do Android) desiste do cadastro: apaga a conta
    // Google recém-criada e volta ao Login (decisão de 27/10/2026).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.cancel();
      },
      child: AuthScaffold(
        onBack: controller.cancel,
        children: [
          const AuthHeader(
            title: 'Falta pouco',
            subtitle:
                'Informe sua data de nascimento e aceite os termos para '
                'terminar de criar sua conta.',
          ),
          SizedBox(height: spacing.xl),
          if (alert != null) ...[alert, SizedBox(height: spacing.lg)],
          // Conta Google em uso.
          Semantics(
            container: true,
            child: Container(
              padding: EdgeInsets.all(spacing.lg),
              decoration: BoxDecoration(
                color: c.surfaceContainer,
                borderRadius: BorderRadius.circular(context.shape.md),
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      LucideIcons.circleUserRound,
                      size: 24,
                      color: c.iconSecondary,
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entrando com o Google',
                          style: textTheme.bodySmall!.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          email,
                          style: textTheme.bodyLarge!.copyWith(
                            color: c.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.xl),
          NexoTextField(
            label: 'Nome',
            controller: _name,
            focusNode: _nameFocus,
            helperText: 'Veio da sua conta Google. Você pode mudar.',
            errorText: controller.errorOf(GoogleFirstAccessField.name),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            enabled: !busy,
            onChanged: controller.changeName,
          ),
          SizedBox(height: spacing.lg),
          NexoDateField(
            label: 'Data de nascimento',
            controller: _birthDate,
            focusNode: _birthDateFocus,
            errorText: controller.errorOf(GoogleFirstAccessField.birthDate),
            firstDate: DateTime(1900),
            lastDate: now,
            initialPickerDate: DateTime(now.year - 18, now.month),
            enabled: !busy,
            onChanged: controller.changeBirthDate,
          ),
          SizedBox(height: spacing.lg),
          LegalConsentField(
            value: state.accepted,
            onChanged: busy ? null : controller.setAccepted,
            onOpenTerms: () => context.push(AppRoutes.terms),
            onOpenPrivacy: () => context.push(AppRoutes.privacy),
          ),
          SizedBox(height: spacing.xl),
          NexoButton.primary(
            label: 'Continuar',
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
        ],
      ),
    );
  }
}
