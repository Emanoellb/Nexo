import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../subjects/application/subject_actions.dart';
import '../../subjects/domain/subject.dart';
import '../../subjects/presentation/subject_form.dart';

/// O que o painel do tópico devolve: salvar (nome e disciplina) ou pedir
/// para excluir (só na edição).
@immutable
class TopicSheetResult {
  const TopicSheetResult.save({required this.name, required this.subjectId})
    : delete = false;

  const TopicSheetResult.delete() : name = '', subjectId = null, delete = true;

  final String name;
  final String? subjectId;
  final bool delete;
}

/// "Novo tópico" / "Editar tópico" (Criar plano 06–08 e Planos 16–17):
/// nome, disciplina (Só deste plano · as disciplinas · Nova disciplina…) e
/// salvar. "Nova disciplina…" troca o conteúdo do mesmo painel, com a seta
/// de voltar, e cria a disciplina para o app inteiro; ela já fica
/// escolhida.
Future<TopicSheetResult?> showTopicSheet(
  BuildContext context, {
  String? name,
  String? subjectId,
  bool editing = false,
}) => showNexoBottomSheetWith<TopicSheetResult>(
  context,
  builder: (_) =>
      _TopicSheet(name: name, subjectId: subjectId, editing: editing),
);

class _TopicSheet extends ConsumerStatefulWidget {
  const _TopicSheet({
    required this.name,
    required this.subjectId,
    required this.editing,
  });

  final String? name;
  final String? subjectId;
  final bool editing;

  @override
  ConsumerState<_TopicSheet> createState() => _TopicSheetState();
}

class _TopicSheetState extends ConsumerState<_TopicSheet> {
  late final _name = TextEditingController(text: widget.name);
  late String? _subjectId = widget.subjectId;
  bool _newSubject = false;
  bool _touched = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickSubject(Rect anchor, List<Subject> subjects) async {
    final chosen = await showNexoMenu(
      context,
      anchor: anchor,
      label: 'Disciplina',
      alignEnd: false,
      items: [
        NexoMenuItem(label: 'Só deste plano', selected: _subjectId == null),
        for (final s in subjects)
          NexoMenuItem(label: s.name, selected: s.id == _subjectId),
        const NexoMenuItem(label: 'Nova disciplina…', icon: LucideIcons.plus),
      ],
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (chosen == 0) {
        _subjectId = null;
      } else if (chosen <= subjects.length) {
        _subjectId = subjects[chosen - 1].id;
      } else {
        _newSubject = true;
      }
    });
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _touched = true);
      return;
    }
    Navigator.of(context)
        .pop(TopicSheetResult.save(name: name, subjectId: _subjectId));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final subjects =
        ref.watch(visibleSubjectsProvider).value ?? const <Subject>[];

    if (_newSubject) {
      return NexoBottomSheet(
        title: 'Nova disciplina',
        onBack: () => setState(() => _newSubject = false),
        child: SubjectForm(
          onCreated: (subject) => setState(() {
            _subjectId = subject.id;
            _newSubject = false;
          }),
        ),
      );
    }

    final subjectName = subjects
        .where((s) => s.id == _subjectId)
        .firstOrNull
        ?.name;
    final empty = _touched && _name.text.trim().isEmpty;

    return NexoBottomSheet(
      title: widget.editing ? 'Editar tópico' : 'Novo tópico',
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NexoTextField(
              label: 'Nome do tópico',
              hintText: 'Ex.: Juros simples',
              controller: _name,
              errorText: empty ? 'Dê um nome ao tópico.' : null,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(80)],
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: spacing.md),
            NexoSelectField(
              label: 'Disciplina',
              leadingIcon: LucideIcons.bookOpen,
              value: subjectName ?? 'Só deste plano',
              placeholder: 'Só deste plano',
              helperText:
                  'Opcional. Reaproveite uma disciplina das tarefas ou '
                  'deixe só no plano.',
              onTap: (anchor) => _pickSubject(anchor, subjects),
            ),
            SizedBox(height: spacing.lg),
            NexoButton.primary(
              label: widget.editing ? 'Salvar' : 'Salvar tópico',
              expand: true,
              onPressed: _save,
            ),
            if (widget.editing) ...[
              SizedBox(height: spacing.sm),
              NexoButton.destructiveLow(
                label: 'Excluir tópico',
                leadingIcon: LucideIcons.trash2,
                expand: true,
                onPressed: () =>
                    Navigator.of(context).pop(const TopicSheetResult.delete()),
              ),
              SizedBox(height: spacing.sm),
              Text(
                "Excluir o tópico não apaga as sessões: elas ficam 'sem "
                "tópico'.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall!
                    .copyWith(color: c.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
