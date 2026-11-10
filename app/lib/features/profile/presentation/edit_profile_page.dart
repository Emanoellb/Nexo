import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_rules.dart';
import '../application/profile_actions.dart';

/// Editar perfil (Perfil 05): só o nome se edita (1 a 80). O e-mail e a
/// data de nascimento ficam só para leitura; corrigir é pelo contato. Sem
/// foto no MVP.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage>
    with LeaveOnce<EditProfilePage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _birth = TextEditingController();
  String? _original;
  bool _showErrors = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _birth.dispose();
    super.dispose();
  }

  bool get _dirty => _original != null && _name.text.trim() != _original;

  String? get _nameError {
    final name = _name.text.trim();
    if (name.isEmpty) return 'Informe seu nome.';
    if (name.length > AuthRules.nameMaxLength) {
      return 'Use até ${AuthRules.nameMaxLength} caracteres.';
    }
    return null;
  }

  Future<void> _close() async {
    if (!_dirty) return leave();
    final discard = await showNexoDiscardDialog(
      context,
      message: 'O nome que você mudou não será salvo.',
    );
    if (discard && mounted) leave();
  }

  Future<void> _save() async {
    if (_nameError != null) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    await ref.read(profileActionsProvider).rename(_name.text);
    if (!mounted) return;
    showNexoSnackbar(context, message: 'Alterações salvas.');
    leave();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final profile = ref.watch(userProfileProvider).value;
    final email = ref.watch(authStateProvider).value?.email ?? '';
    final bar = NexoTopAppBar(title: 'Editar perfil', onBack: _close);
    if (profile == null) {
      return Scaffold(appBar: bar, body: const SizedBox.expand());
    }
    if (_original == null) {
      _original = profile.displayName;
      _name.text = profile.displayName;
      _email.text = email;
      final birth = profile.birthDate;
      _birth.text = birth == null
          ? ''
          : '${birth.day.toString().padLeft(2, '0')}/'
                '${birth.month.toString().padLeft(2, '0')}/${birth.year}';
    }
    const readOnlyHelp =
        'Não dá para mudar no app. Precisa corrigir? Fale com a gente.';

    return PopScope(
      canPop: !_dirty || leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: bar,
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
              NexoTextField(
                label: 'Nome',
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                errorText: _showErrors ? _nameError : null,
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: spacing.lg),
              NexoTextField(
                label: 'E-mail',
                controller: _email,
                enabled: false,
                helperText: 'Somente leitura.',
              ),
              SizedBox(height: spacing.lg),
              NexoTextField(
                label: 'Data de nascimento',
                controller: _birth,
                enabled: false,
                leadingIcon: LucideIcons.calendar,
                helperText: readOnlyHelp,
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
              spacing.xl,
            ),
            child: NexoButton.primary(
              label: 'Salvar',
              leadingIcon: LucideIcons.check,
              expand: true,
              loading: _saving,
              onPressed: _dirty ? _save : null,
            ),
          ),
        ),
      ),
    );
  }
}
