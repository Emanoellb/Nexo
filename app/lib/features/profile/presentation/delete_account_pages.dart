import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../auth/application/account_deletion.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_failure.dart';

/// O que some com a conta (Perfil 07).
const _erased = [
  'Planos, sessões de foco, dias e relatórios',
  'Tarefas e disciplinas',
  'Objetivos',
  'Pontos, nível e medalhas',
  'Seus dados de cadastro e o acesso ao Nexo',
];

/// Excluir conta, passo 1 (Perfil 07): "Isso não tem volta", a lista do que
/// será apagado e a caixa obrigatória; Continuar (Destructive/High).
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: NexoTopAppBar(
        title: 'Excluir conta',
        onBack: () => context.pop(),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          spacing.lg,
          spacing.sm,
          spacing.lg,
          spacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NexoAlert(
              tone: NexoAlertTone.error,
              icon: LucideIcons.triangleAlert,
              title: 'Excluir conta?',
              message: 'Sua conta e tudo o que está nela serão apagados.',
            ),
            SizedBox(height: spacing.lg),
            Semantics(
              header: true,
              child: Text(
                'Será apagado:',
                style: textTheme.titleSmall!.copyWith(color: c.onSurface),
              ),
            ),
            SizedBox(height: spacing.sm),
            for (final item in _erased)
              Padding(
                padding: EdgeInsets.symmetric(vertical: spacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.x, size: 16, color: c.iconError),
                    SizedBox(width: spacing.sm),
                    Expanded(
                      child: Text(
                        item,
                        style: textTheme.bodyMedium!.copyWith(
                          color: c.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: spacing.md),
            NexoCheckbox(
              value: _understood,
              labelText: 'Desejo excluir minha conta e entendo que isso não tem volta.',
              onChanged: (v) => setState(() => _understood = v),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NexoScreenFooter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.sm,
            spacing.lg,
            spacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NexoButton.destructiveHigh(
                label: 'Continuar',
                expand: true,
                onPressed: _understood
                    ? () => context.push(AppRoutes.confirmDeletion)
                    : null,
              ),
              SizedBox(height: spacing.sm),
              NexoButton.tertiary(
                label: 'Cancelar',
                expand: true,
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Excluir conta, passo 2 (Perfil 08): entrar de novo (senha ou Google) e
/// "Excluir conta". Confirmado, grava `deletionRequestedAt` e a entrada leva
/// à tela 09.
class ConfirmDeletionPage extends ConsumerStatefulWidget {
  const ConfirmDeletionPage({super.key});

  @override
  ConsumerState<ConfirmDeletionPage> createState() =>
      _ConfirmDeletionPageState();
}

class _ConfirmDeletionPageState extends ConsumerState<ConfirmDeletionPage> {
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  /// Conta Google: "Continuar com o Google" confirmou quem é; libera o
  /// "Excluir conta".
  bool _googleConfirmed = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm({required bool google}) async {
    final auth = ref.read(authRepositoryProvider);
    if (!google && _password.text.isEmpty) {
      setState(() => _error = 'Digite sua senha.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (google) {
        if (!_googleConfirmed) {
          final ok = await auth.reauthenticateWithGoogle();
          if (mounted) {
            setState(() {
              _busy = false;
              _googleConfirmed = ok;
            });
          }
          return;
        }
      } else {
        await auth.reauthenticateWithPassword(_password.text);
      }
      await ref.read(accountDeletionProvider).request();
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (failure.code) {
          AuthFailureCode.invalidCredential => 'Senha incorreta.',
          AuthFailureCode.network =>
            'Sem conexão. Confira a internet e tente de novo.',
          AuthFailureCode.tooManyRequests =>
            'Muitas tentativas. Espere um pouco e tente de novo.',
          _ => 'Não foi possível confirmar. Tente de novo.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final google =
        ref.watch(authStateProvider).value?.signedInWithGoogle ?? false;
    return Scaffold(
      appBar: NexoTopAppBar(
        title: 'Confirmar exclusão',
        onBack: () => context.pop(),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          spacing.lg,
          spacing.sm,
          spacing.lg,
          spacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Para sua segurança, entre de novo para confirmar.',
              style: Theme.of(context).textTheme.bodyMedium!
                  .copyWith(color: c.onSurfaceVariant),
            ),
            SizedBox(height: spacing.lg),
            if (google) ...[
              NexoGoogleButton(
                label: _googleConfirmed
                    ? 'Conta Google confirmada'
                    : 'Continuar com o Google',
                loading: _busy && !_googleConfirmed,
                onPressed: _busy || _googleConfirmed
                    ? null
                    : () => _confirm(google: true),
              ),
              if (_error != null) ...[
                SizedBox(height: spacing.sm),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall!
                      .copyWith(color: c.error),
                ),
              ],
            ] else ...[
              NexoTextField(
                label: 'Senha',
                controller: _password,
                obscurable: true,
                autofillHints: const [AutofillHints.password],
                errorText: _error,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: NexoButton.tertiary(
                  label: 'Esqueci minha senha',
                  onPressed: () => context.push(AppRoutes.forgotPassword),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: NexoScreenFooter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.sm,
            spacing.lg,
            spacing.xl,
          ),
          child: NexoButton.destructiveHigh(
            label: 'Excluir conta',
            expand: true,
            loading: _busy && (!google || _googleConfirmed),
            onPressed: _busy || (google && !_googleConfirmed)
                ? null
                : () => _confirm(google: google),
          ),
        ),
      ),
    );
  }
}

/// Excluir conta, passo 3 (Perfil 09): "Excluindo sua conta…", sem saída.
/// Também abre no login seguinte, se o app fechou no meio
/// (`deletionRequestedAt`). No fim, o Login com "Conta excluída.".
class DeletingAccountPage extends ConsumerStatefulWidget {
  const DeletingAccountPage({super.key});

  @override
  ConsumerState<DeletingAccountPage> createState() =>
      _DeletingAccountPageState();
}

class _DeletingAccountPageState extends ConsumerState<DeletingAccountPage> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (!mounted) return;
    setState(() => _failed = false);
    try {
      await ref.read(accountDeletionProvider).finish();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_failed) ...[
                    const NexoCircularProgress(
                      semanticsLabel: 'Excluindo sua conta',
                    ),
                    SizedBox(height: spacing.lg),
                  ],
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _failed
                          ? 'Não foi possível terminar a exclusão'
                          : 'Excluindo sua conta…',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium!.copyWith(
                        color: c.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    _failed
                        ? 'Confira a internet e tente de novo. O que já foi '
                              'apagado não volta.'
                        : 'Isso pode levar alguns segundos. Não feche o app.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall!.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                  if (_failed) ...[
                    SizedBox(height: spacing.lg),
                    NexoButton.primary(
                      label: 'Tentar de novo',
                      onPressed: _run,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
