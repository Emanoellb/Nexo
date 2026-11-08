import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../application/subject_actions.dart';
import '../../tasks/presentation/task_list.dart';
import '../domain/subject.dart';
import 'subject_icon.dart';

/// Como o cadastro de disciplina fechou.
enum SubjectFormResult { saved, deleteRequested }

/// Cadastro ("Nova disciplina") ou edição ("Editar disciplina") num
/// BottomSheet (design de 04/11/2026): nome (obrigatório, até 80, sem
/// repetir) e um dos 12 ícones. Na edição, "Excluir disciplina" fecha o
/// painel e devolve [SubjectFormResult.deleteRequested]: quem abriu exclui
/// (com "Desfazer").
///
/// Ao criar, confirma com a Snackbar "Disciplina criada." (pedido do
/// usuário, 06/11/2026); a nova linha já aparece na lista.
Future<SubjectFormResult?> showSubjectForm(
  BuildContext context, {
  Subject? editing,
}) async {
  final result = await showNexoBottomSheet<SubjectFormResult>(
    context,
    title: editing == null ? 'Nova disciplina' : 'Editar disciplina',
    builder: (_) => SubjectForm(editing: editing),
  );
  if (result == SubjectFormResult.saved && editing == null && context.mounted) {
    showNexoSnackbar(context, message: 'Disciplina criada.');
  }
  return result;
}

/// Dialog destrutivo antes de excluir a disciplina (pedido do usuário,
/// 06/11/2026): explica que as tarefas continuam. `true` = excluir.
Future<bool> confirmDeleteSubject(BuildContext context, Subject subject) =>
    showNexoDialog(
      context,
      icon: LucideIcons.trash2,
      title: 'Excluir disciplina?',
      message:
          '"${subject.name}" sai da sua lista. As tarefas dela continuam no '
          'app, sem disciplina.',
      confirmLabel: 'Excluir disciplina',
      destructive: true,
    );

/// Exclui com "Desfazer": a disciplina some na hora e só é apagada quando
/// a Snackbar some. As tarefas dela continuam, sem disciplina.
void deleteSubjectWithUndo(
  BuildContext context,
  WidgetRef ref,
  String subjectId,
) => deleteWithUndo(
  context,
  ref.read(subjectDeletionProvider),
  subjectId,
  message: 'Disciplina excluída.',
);

class SubjectForm extends ConsumerStatefulWidget {
  const SubjectForm({super.key, this.editing, this.onCreated});

  final Subject? editing;

  /// Dentro de outro painel (ex.: "Nova disciplina" no tópico do plano):
  /// recebe a disciplina criada em vez de fechar o painel.
  final ValueChanged<Subject>? onCreated;

  @override
  ConsumerState<SubjectForm> createState() => _SubjectFormState();
}

class _SubjectFormState extends ConsumerState<SubjectForm> {
  late final _name = TextEditingController(text: widget.editing?.name);
  final _focus = FocusNode();
  late String _icon = widget.editing?.icon ?? subjectIcons.first;

  /// O erro de "Informe o nome" só aparece depois de a pessoa mexer.
  bool _touched = false;
  bool _saving = false;

  /// Erro da última tentativa de salvar; some ao editar o nome.
  String? _saveError;

  @override
  void initState() {
    super.initState();
    // Foco no nome ao abrir: o painel sobe junto com o teclado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  String? _error(List<Subject> existing) {
    final error = subjectNameError(
      _name.text,
      existing,
      editingId: widget.editing?.id,
    );
    if (_name.text.trim().isEmpty && !_touched) return null;
    return error;
  }

  Future<void> _save(List<Subject> existing) async {
    setState(() => _touched = true);
    if (_error(existing) != null) return;
    setState(() => _saving = true);
    final actions = ref.read(subjectActionsProvider);
    final navigator = Navigator.of(context);
    final editing = widget.editing;
    try {
      if (editing == null) {
        final created = await actions.create(name: _name.text, icon: _icon);
        final onCreated = widget.onCreated;
        if (onCreated != null) {
          if (mounted) onCreated(created);
          return;
        }
      } else {
        await actions.update(editing, name: _name.text, icon: _icon);
      }
    } on Object {
      // Falhou (ex.: sem conexão, no bloco de integração): o painel volta a
      // aceitar o toque e avisa no próprio campo (uma Snackbar ficaria atrás
      // do painel), sem perder o que foi digitado.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Não foi possível salvar. Tente de novo.';
      });
      return;
    }
    navigator.pop(SubjectFormResult.saved);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final existing =
        ref.watch(visibleSubjectsProvider).value ?? const <Subject>[];
    final invalid = _error(existing);
    final error = invalid ?? _saveError;
    // Depois de uma falha, dá para tentar de novo sem editar.
    final canSave = !_saving && _name.text.trim().isNotEmpty && invalid == null;
    final editing = widget.editing != null;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Design (Tarefas 15–17): formulário com LG entre os blocos.
          NexoTextField(
            label: 'Nome',
            hintText: 'Ex.: Estatística',
            controller: _name,
            focusNode: _focus,
            errorText: error,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              LengthLimitingTextInputFormatter(Subject.maxNameLength),
            ],
            onChanged: (_) => setState(() {
              _touched = true;
              _saveError = null;
            }),
            onSubmitted: canSave ? (_) => _save(existing) : null,
          ),
          SizedBox(height: spacing.lg),
          Semantics(
            header: true,
            child: Text(
              'Ícone',
              style: context
                  .textStyle(NexoTextStyles.labelMediumEmphasis)
                  .copyWith(color: c.onSurface),
            ),
          ),
          SizedBox(height: spacing.sm),
          // Duas linhas de 6, distribuídas na largura (design).
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: [
              for (final name in subjectIcons)
                _IconTile(
                  name: name,
                  selected: name == _icon,
                  onTap: () => setState(() => _icon = name),
                ),
            ],
          ),
          SizedBox(height: spacing.lg),
          NexoButton.primary(
            label: editing ? 'Salvar alterações' : 'Salvar disciplina',
            expand: true,
            loading: _saving,
            onPressed: canSave ? () => _save(existing) : null,
          ),
          if (editing) ...[
            SizedBox(height: spacing.lg),
            NexoButton.destructiveLow(
              label: 'Excluir disciplina',
              expand: true,
              onPressed: _saving
                  ? null
                  : () =>
                        Navigator.of(context)
                            .pop(SubjectFormResult.deleteRequested),
            ),
          ],
        ],
      ),
    );
  }
}

/// Um ícone da grade: 48 × 48 em `Shape/MD`; o escolhido em
/// PrimaryContainer com borda de 2 px Primary (não só cor: borda e fundo).
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final data = subjectIconData[name]!;
    final size = context.sizes.target;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: 'Ícone ${data.label}',
      onTap: onTap,
      excludeSemantics: true,
      child: NexoTappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.shape.md),
        color: selected ? c.primaryContainer : c.surfaceContainer,
        side: selected
            ? BorderSide(color: c.primary, width: 2)
            : BorderSide.none,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            data.icon,
            size: 24,
            color: selected ? c.onPrimaryContainer : c.iconSecondary,
          ),
        ),
      ),
    );
  }
}
