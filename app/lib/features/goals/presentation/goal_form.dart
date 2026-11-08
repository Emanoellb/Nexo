import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/domain/local_date.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../tasks/application/screen_now.dart';
import '../application/goal_actions.dart';
import '../domain/goal.dart';

/// "Novo objetivo" / "Editar objetivo" (Planos 10): nome, descrição e prazo
/// opcionais. Devolve o objetivo salvo, ou `null`.
Future<Goal?> showGoalForm(BuildContext context, {Goal? editing}) async {
  final goal = await showNexoBottomSheet<Goal>(
    context,
    title: editing == null ? 'Novo objetivo' : 'Editar objetivo',
    builder: (_) => _GoalForm(editing: editing),
  );
  if (goal != null && editing == null && context.mounted) {
    showNexoSnackbar(
      context,
      message: 'Objetivo criado.',
      tone: NexoSnackbarTone.success,
    );
  }
  return goal;
}

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm({this.editing});

  final Goal? editing;

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  late final _name = TextEditingController(text: widget.editing?.name);
  late final _description = TextEditingController(
    text: widget.editing?.description,
  );
  late LocalDate? _deadline = widget.editing?.deadline;
  bool _touched = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline(Rect anchor) async {
    final now = ref.read(screenNowProvider);
    final today = DateTime(now.year, now.month, now.day);
    final pick = await pickOptionalDate(
      context,
      anchor: anchor,
      label: 'Prazo',
      clearLabel: 'Sem prazo',
      current: _deadline,
      firstDate: today,
      lastDate: DateTime(now.year + 10, 12, 31),
      fallbackInitial: today,
    );
    if (pick != null && mounted) setState(() => _deadline = pick.date);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _touched = true);
      return;
    }
    setState(() => _saving = true);
    final actions = ref.read(goalActionsProvider);
    final navigator = Navigator.of(context);
    final description = _description.text.trim();
    final editing = widget.editing;
    final Goal goal;
    if (editing == null) {
      goal = await actions.create(
        name: name,
        description: description.isEmpty ? null : description,
        deadline: _deadline,
      );
    } else {
      goal = editing.copyWith(
        name: name,
        description: () => description.isEmpty ? null : description,
        deadline: () => _deadline,
      );
      await actions.update(goal);
    }
    navigator.pop(goal);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final empty = _touched && _name.text.trim().isEmpty;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NexoTextField(
            label: 'Nome',
            hintText: 'Ex.: Intercâmbio em Dublin',
            controller: _name,
            errorText: empty ? 'Dê um nome ao objetivo.' : null,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(80)],
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: spacing.md),
          NexoTextField(
            label: 'Descrição',
            hintText: 'Ex.: Morar seis meses na Irlanda e estudar inglês.',
            helperText: 'Opcional · até 500 caracteres.',
            controller: _description,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            inputFormatters: [LengthLimitingTextInputFormatter(500)],
          ),
          SizedBox(height: spacing.md),
          NexoSelectField(
            label: 'Prazo',
            trailingIcon: LucideIcons.calendar,
            value: _deadline?.toDisplay(),
            placeholder: 'Sem prazo',
            helperText: 'Opcional.',
            onTap: _pickDeadline,
          ),
          SizedBox(height: spacing.lg),
          NexoButton.primary(
            label: widget.editing == null ? 'Salvar objetivo' : 'Salvar',
            expand: true,
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
