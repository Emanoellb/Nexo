import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/domain/local_date.dart';
import '../../../core/theme/nexo_theme.dart';
import '../../../core/ui/ui.dart';
import '../../progress/application/progress_actions.dart';
import '../../subjects/application/subject_actions.dart';
import '../../subjects/domain/subject.dart';
import '../../subjects/presentation/subject_form.dart';
import '../application/screen_now.dart';
import '../application/task_actions.dart';
import '../application/tasks_providers.dart';
import '../domain/task.dart';
import '../domain/task_rules.dart';
import 'task_list.dart';
import 'task_text.dart';

/// Ícone da situação da entrega (design da Tarefa, 07/11/2026), em
/// Icon/Secondary. "Sem situação" fica sem ícone.
IconData deliveryStatusIcon(DeliveryStatus status) => switch (status) {
  DeliveryStatus.notStarted => LucideIcons.circleDashed,
  DeliveryStatus.inProgress => LucideIcons.circleDot,
  DeliveryStatus.delivered => LucideIcons.send,
  DeliveryStatus.awaitingGrade => LucideIcons.hourglass,
};

/// Rótulos do `Selection/Segmented` de prioridade.
const _priorityLabels = {
  TaskPriority.none: 'Nenhuma',
  TaskPriority.low: 'Baixa',
  TaskPriority.medium: 'Média',
  TaskPriority.high: 'Alta',
};

/// Sem hora, o prazo vale 23:59 (especificação da Tarefa).
const _endOfDay = TimeOfDay(hour: 23, minute: 59);

/// O que o formulário edita. Comparar dois valores diz se há alteração.
@immutable
class _FormValues {
  const _FormValues({
    required this.title,
    required this.subjectId,
    required this.day,
    required this.time,
    required this.reminders,
    required this.priority,
    required this.status,
  });

  _FormValues.of(NexoTask task)
    : title = task.title,
      subjectId = task.subjectId,
      day = task.dueAt == null ? null : LocalDate.fromDateTime(task.dueAt!),
      time = task.dueAt == null ? null : TimeOfDay.fromDateTime(task.dueAt!),
      reminders = task.remindersMinutesBefore,
      priority = task.priority,
      status = task.deliveryStatus;

  static const empty = _FormValues(
    title: '',
    subjectId: null,
    day: null,
    time: null,
    reminders: [],
    priority: TaskPriority.none,
    status: null,
  );

  final String title;
  final String? subjectId;
  final LocalDate? day;
  final TimeOfDay? time;
  final List<int> reminders;
  final TaskPriority priority;
  final DeliveryStatus? status;

  DateTime? get dueAt {
    final d = day;
    if (d == null) return null;
    final t = time ?? _endOfDay;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  _FormValues copyWith({
    String? title,
    String? Function()? subjectId,
    LocalDate? Function()? day,
    TimeOfDay? Function()? time,
    List<int>? reminders,
    TaskPriority? priority,
    DeliveryStatus? Function()? status,
  }) => _FormValues(
    title: title ?? this.title,
    subjectId: subjectId == null ? this.subjectId : subjectId(),
    day: day == null ? this.day : day(),
    time: time == null ? this.time : time(),
    reminders: reminders ?? this.reminders,
    priority: priority ?? this.priority,
    status: status == null ? this.status : status(),
  );

  @override
  bool operator ==(Object other) =>
      other is _FormValues &&
      other.title.trim() == title.trim() &&
      other.subjectId == subjectId &&
      other.day == day &&
      other.time == time &&
      listEquals(other.reminders, reminders) &&
      other.priority == priority &&
      other.status == status;

  @override
  int get hashCode => Object.hash(
    title.trim(),
    subjectId,
    day,
    time,
    Object.hashAll(reminders),
    priority,
    status,
  );
}

/// Nova tarefa (tela cheia, com X) e detalhe da tarefa (já editável), do
/// design da Tarefa (07/11/2026). Um formulário em 3 blocos, sem títulos de
/// grupo: título e disciplina; prazo, hora e avisos; prioridade e situação.
///
/// - Nova tarefa: "Criar tarefa" (Primary). Fecha e mostra "Tarefa
///   criada." onde a pessoa estava.
/// - Detalhe: sem alterações, "Marcar como concluída" ou "Reabrir tarefa"
///   (Secondary); com alterações, "Salvar" (Primary). O ⋯ só exclui, com
///   "Desfazer" e sem confirmação.
/// - Sair com alterações pergunta "Descartar alterações?".
class TaskFormPage extends ConsumerStatefulWidget {
  const TaskFormPage.create({super.key}) : taskId = null;

  const TaskFormPage.detail({super.key, required String this.taskId});

  /// `null` = Nova tarefa.
  final String? taskId;

  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage>
    with
        LeaveOnce<TaskFormPage>,
        TaskListActions<TaskFormPage>,
        ScreenNowRefresh<TaskFormPage> {
  final _title = TextEditingController();
  final _titleFocus = FocusNode();
  final _moreKey = GlobalKey();
  final _addReminderKey = GlobalKey();

  /// Valores gravados (detalhe) ou vazios (nova): a base para saber se
  /// houve alteração.
  _FormValues _saved = _FormValues.empty;
  _FormValues _values = _FormValues.empty;
  bool _loaded = false;
  bool _titleError = false;
  bool _saving = false;

  bool get _isNew => widget.taskId == null;
  bool get _dirty => _values != _saved;

  @override
  void initState() {
    super.initState();
    if (_isNew) _loaded = true;
  }

  @override
  void dispose() {
    _title.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  /// Detalhe: carrega da tarefa gravada. Sem alterações pendentes, segue
  /// as mudanças de fora (concluir, reabrir, Desfazer).
  void _sync(NexoTask task) {
    final fromStore = _FormValues.of(task);
    if (_loaded && (_dirty || fromStore == _saved)) return;
    _saved = fromStore;
    _values = fromStore;
    if (_title.text != task.title) _title.text = task.title;
    _loaded = true;
  }

  void _set(_FormValues values) => setState(() => _values = values);

  Future<void> _confirmLeave() async {
    final discard = await showNexoDiscardDialog(
      context,
      message: 'As mudanças nesta tarefa não serão salvas.',
    );
    if (discard && mounted) leave();
  }

  void _back() => _dirty ? _confirmLeave() : leave();

  // ---------- Campos ----------

  Future<void> _pickSubject(Rect anchor, List<Subject> subjects) async {
    final sorted = [...subjects]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final chosen = await showNexoMenu(
      context,
      anchor: anchor,
      label: 'Disciplina',
      alignEnd: false,
      items: [
        for (final s in sorted)
          NexoMenuItem(label: s.name, selected: s.id == _values.subjectId),
        NexoMenuItem(
          label: 'Sem disciplina',
          selected: _values.subjectId == null,
        ),
        const NexoMenuItem(label: 'Nova disciplina', icon: LucideIcons.plus),
      ],
    );
    if (chosen == null || !mounted) return;
    if (chosen < sorted.length) {
      _set(_values.copyWith(subjectId: () => sorted[chosen].id));
    } else if (chosen == sorted.length) {
      _set(_values.copyWith(subjectId: () => null));
    } else {
      await _newSubject(subjects);
    }
  }

  /// "Nova disciplina": o painel de sempre; a criada já fica escolhida.
  Future<void> _newSubject(List<Subject> before) async {
    final known = {for (final s in before) s.id};
    final result = await showSubjectForm(context);
    if (result != SubjectFormResult.saved || !mounted) return;
    final created = (ref.read(visibleSubjectsProvider).value ?? const [])
        .where((s) => !known.contains(s.id))
        .firstOrNull;
    if (created != null) _set(_values.copyWith(subjectId: () => created.id));
  }

  Future<void> _pickDay(Rect anchor) async {
    final now = ref.read(screenNowProvider);
    final pick = await pickOptionalDate(
      context,
      anchor: anchor,
      label: 'Prazo',
      clearLabel: 'Sem prazo',
      current: _values.day,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      fallbackInitial: DateTime(now.year, now.month, now.day),
    );
    if (pick == null || !mounted) return;
    final day = pick.date;
    if (day == null) {
      // Sem prazo, sem avisos (as regras negam aviso sem prazo).
      _set(
        _values.copyWith(
          day: () => null,
          time: () => null,
          reminders: const [],
        ),
      );
      return;
    }
    final hadDay = _values.day != null;
    _set(
      _values.copyWith(
        day: () => day,
        // Ao escolher um prazo, o aviso já vem em "1 dia antes".
        reminders: hadDay ? null : TaskReminder.suggested,
      ),
    );
  }

  Future<void> _pickTime(Rect anchor) async {
    if (_values.time != null) {
      final chosen = await showNexoMenu(
        context,
        anchor: anchor,
        label: 'Hora',
        items: const [
          NexoMenuItem(label: 'Escolher horário', icon: LucideIcons.clock3),
          NexoMenuItem(label: 'Sem horário', icon: LucideIcons.x),
        ],
      );
      if (chosen == null || !mounted) return;
      if (chosen == 1) {
        _set(_values.copyWith(time: () => null));
        return;
      }
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: _values.time ?? const TimeOfDay(hour: 18, minute: 0),
      helpText: 'Hora',
    );
    if (picked == null || !mounted) return;
    _set(_values.copyWith(time: () => picked));
  }

  void _addReminder(int minutes) {
    final list = _values.reminders;
    if (list.contains(minutes) || list.length >= TaskReminder.maxCount) return;
    _set(
      _values.copyWith(reminders: [...list, minutes]..sort((a, b) => b - a)),
    );
  }

  Future<void> _openReminderMenu() async {
    final box =
        _addReminderKey.currentContext!.findRenderObject()! as RenderBox;
    final list = _values.reminders;
    const presets = [
      (TaskReminder.oneHour, '1 hora antes'),
      (TaskReminder.oneDay, '1 dia antes'),
      (TaskReminder.oneWeek, '1 semana antes'),
    ];
    final chosen = await showNexoMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      label: 'Adicionar aviso',
      alignEnd: false,
      items: [
        for (final (minutes, label) in presets)
          NexoMenuItem(label: label, selected: list.contains(minutes)),
        const NexoMenuItem(label: 'Personalizado…'),
      ],
    );
    if (chosen == null || !mounted) return;
    if (chosen < presets.length) {
      _addReminder(presets[chosen].$1);
      return;
    }
    final custom = await showNexoBottomSheet<int>(
      context,
      title: 'Novo aviso',
      builder: (_) => _CustomReminderForm(existing: list),
    );
    if (custom != null && mounted) _addReminder(custom);
  }

  Future<void> _pickStatus(Rect anchor, bool completed) async {
    final options = <DeliveryStatus?>[
      null,
      for (final s in DeliveryStatus.values)
        if (s.isPending != completed) s,
    ];
    final chosen = await showNexoMenu(
      context,
      anchor: anchor,
      label: 'Situação da entrega',
      alignEnd: false,
      items: [
        for (final s in options)
          NexoMenuItem(
            label: s?.label ?? 'Sem situação',
            icon: s == null ? null : deliveryStatusIcon(s),
            selected: s == _values.status,
          ),
      ],
    );
    if (chosen == null || !mounted) return;
    _set(_values.copyWith(status: () => options[chosen]));
  }

  // ---------- Ações ----------

  bool _validTitle() {
    if (_values.title.trim().isNotEmpty) return true;
    setState(() => _titleError = true);
    _titleFocus.requestFocus();
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Dê um título à tarefa.',
      Directionality.of(context),
    );
    return false;
  }

  NexoTask _build(NexoTask base) => NexoTask(
    id: base.id,
    title: _values.title.trim(),
    priority: _values.priority,
    completed: base.completed,
    completedAt: base.completedAt,
    subjectId: _values.subjectId,
    dueAt: _values.dueAt,
    remindersMinutesBefore: _values.dueAt == null
        ? const []
        : _values.reminders,
    deliveryStatus: _values.status,
  );

  Future<void> _create() async {
    if (_saving || !_validTitle()) return;
    setState(() => _saving = true);
    final repository = ref.read(tasksRepositoryProvider);
    final task = _build(NexoTask(id: '', title: '-'));
    // A Snackbar é do app: aparece na tela de onde a pessoa veio. Entra na
    // fila antes de gravar: se a tarefa concluir os "Primeiros passos", o
    // Início troca a fila pelo aviso dele (estado 05), sem os dois.
    showNexoSnackbar(context, message: 'Tarefa criada.', queue: true);
    await repository.createTask(task);
    if (mounted) leave();
  }

  Future<void> _save(NexoTask task) async {
    if (_saving || !_validTitle()) return;
    setState(() => _saving = true);
    await ref.read(tasksRepositoryProvider).updateTask(_build(task));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = _values;
    });
    showNexoSnackbar(context, message: 'Alterações salvas.');
  }

  Future<void> _reopen(NexoTask task) async {
    final progress = ref.read(progressActionsProvider);
    await progress.setTaskCompleted(task.id, false);
    if (!mounted) return;
    showNexoSnackbar(
      context,
      message: 'Tarefa reaberta. −1 ponto',
      actionLabel: 'Desfazer',
      onAction: () => progress.setTaskCompleted(task.id, true),
    );
  }

  Future<void> _more(NexoTask task) async {
    final box = _moreKey.currentContext!.findRenderObject()! as RenderBox;
    final chosen = await showNexoMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      label: 'Mais opções',
      items: const [
        NexoMenuItem(
          label: 'Excluir tarefa',
          icon: LucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (chosen != 0 || !mounted) return;
    // Sem confirmação: a tela fecha e a Snackbar com "Desfazer" fica na
    // tela de baixo (igual à Tarefas 10).
    deleteTask(task);
    leave();
  }

  // ---------- Tela ----------

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    final spacing = context.spacing;
    final now = ref.watch(screenNowProvider);
    final subjects =
        ref.watch(visibleSubjectsProvider).value ?? const <Subject>[];

    NexoTask? task;
    if (!_isNew) {
      final tasks = ref.watch(visibleTasksProvider);
      task = tasks.value?.where((t) => t.id == widget.taskId).firstOrNull;
      if (task != null) {
        _sync(task);
        scheduleNowRefresh([task]);
      } else if (tasks.hasValue) {
        // Excluída (aqui ou em outro lugar): sai.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) leave();
        });
      }
    }

    final bar = NexoTopAppBar(
      title: _isNew ? 'Nova tarefa' : 'Tarefa',
      closeIcon: _isNew,
      onBack: _back,
      actions: [
        if (!_isNew)
          NexoIconButton(
            key: _moreKey,
            icon: LucideIcons.ellipsis,
            tooltip: 'Mais opções',
            color: c.iconDefault,
            onPressed: task == null ? null : () => _more(task!),
          ),
      ],
    );

    if (!_loaded || (!_isNew && task == null)) {
      return Scaffold(appBar: bar, body: const SizedBox.expand());
    }

    final completed = task?.completed ?? false;
    final subjectName = subjects
        .where((s) => s.id == _values.subjectId)
        .firstOrNull
        ?.name;
    final due = _values.dueAt;
    // Atrasada só pelo que está gravado (o prazo em edição ainda não vale).
    final summary = task == null
        ? null
        : taskSummaryText(
            completed: task.completed,
            completedAt: task.completedAt,
            dueAt: task.dueAt,
            now: now,
          );
    final overdueText = summary != null && summary.overdue && !_dirty
        ? summary.text
        : null;
    final reminders = _values.reminders;
    final full = reminders.length >= TaskReminder.maxCount;

    Widget label(String text) => ExcludeSemantics(
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium!
            .copyWith(color: c.onSurface),
      ),
    );
    Widget help(String text) => Text(
      text,
      style: Theme.of(context).textTheme.bodySmall!
          .copyWith(color: c.onSurfaceVariant),
    );

    final form = <Widget>[
      if (summary != null) ...[
        _Summary(
          text: summary.text,
          overdue: summary.overdue,
          icon: task!.deliveryStatus == null
              ? null
              : deliveryStatusIcon(task.deliveryStatus!),
        ),
        SizedBox(height: spacing.lg),
      ],
      // Bloco 1: o quê.
      NexoTextField(
        label: 'Título',
        hintText: 'Ex.: Lista de exercícios 4',
        controller: _title,
        focusNode: _titleFocus,
        errorText: _titleError ? 'Dê um título à tarefa.' : null,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        inputFormatters: [LengthLimitingTextInputFormatter(200)],
        onChanged: (text) => setState(() {
          _values = _values.copyWith(title: text);
          if (text.trim().isNotEmpty) _titleError = false;
        }),
      ),
      SizedBox(height: spacing.md),
      NexoSelectField(
        label: 'Disciplina',
        leadingIcon: LucideIcons.bookOpen,
        value: subjectName,
        placeholder: 'Sem disciplina',
        onTap: (anchor) => _pickSubject(anchor, subjects),
      ),
      SizedBox(height: spacing.lg),
      // Bloco 2: quando.
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: NexoSelectField(
              label: 'Prazo',
              trailingIcon: LucideIcons.calendar,
              value: _values.day == null
                  ? null
                  : dueDateFieldText(_values.day!, LocalDate.fromDateTime(now)),
              placeholder: 'Sem prazo',
              errorText: overdueText,
              onTap: _pickDay,
            ),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            flex: 2,
            child: NexoSelectField(
              label: 'Hora',
              trailingIcon: LucideIcons.clock3,
              value: _values.time == null
                  ? null
                  : hhmm(
                      DateTime(
                        0,
                        1,
                        1,
                        _values.time!.hour,
                        _values.time!.minute,
                      ),
                    ),
              placeholder: '—',
              onTap: _values.day == null ? null : _pickTime,
            ),
          ),
        ],
      ),
      if (due != null) ...[
        SizedBox(height: spacing.md),
        label('Avisos de entrega'),
        SizedBox(height: spacing.sm),
        if (reminders.isNotEmpty)
          Wrap(
            spacing: spacing.sm,
            children: [
              for (final m in reminders)
                NexoInputChip(
                  key: ValueKey(m),
                  label: reminderLabel(m),
                  removeLabel: 'Remover aviso de ${reminderLabel(m)}',
                  onRemove: () => _set(
                    _values.copyWith(reminders: [...reminders]..remove(m)),
                  ),
                ),
            ],
          ),
        if (!completed && !full)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: NexoButton.tertiary(
              key: _addReminderKey,
              label: 'Adicionar aviso',
              leadingIcon: LucideIcons.plus,
              onPressed: _openReminderMenu,
            ),
          ),
        SizedBox(height: spacing.xs),
        help(
          completed
              ? 'Avisos desligados: tarefa concluída.'
              : full
              ? 'Máximo de 3 avisos.'
              : 'Antes do prazo · até 3 avisos.',
        ),
      ],
      SizedBox(height: spacing.lg),
      // Bloco 3: como está.
      Semantics(header: true, child: label('Prioridade')),
      SizedBox(height: spacing.sm),
      Semantics(
        label: 'Prioridade',
        container: true,
        child: NexoSegmented<TaskPriority>(
          segments: [
            for (final p in [
              TaskPriority.none,
              TaskPriority.low,
              TaskPriority.medium,
              TaskPriority.high,
            ])
              (value: p, label: _priorityLabels[p]!),
          ],
          selected: _values.priority,
          onChanged: (p) => _set(_values.copyWith(priority: p)),
        ),
      ),
      SizedBox(height: spacing.md),
      NexoSelectField(
        label: 'Situação da entrega',
        leadingIcon: _values.status == null
            ? null
            : deliveryStatusIcon(_values.status!),
        value: _values.status?.label,
        placeholder: 'Sem situação',
        onTap: (anchor) => _pickStatus(anchor, completed),
      ),
    ];

    final Widget action;
    if (_isNew) {
      action = NexoButton.primary(
        label: 'Criar tarefa',
        leadingIcon: LucideIcons.plus,
        expand: true,
        loading: _saving,
        onPressed: _create,
      );
    } else if (_dirty) {
      action = NexoButton.primary(
        label: 'Salvar',
        leadingIcon: LucideIcons.check,
        expand: true,
        loading: _saving,
        onPressed: () => _save(task!),
      );
    } else if (completed) {
      action = NexoButton.secondary(
        label: 'Reabrir tarefa',
        leadingIcon: LucideIcons.rotateCcw,
        expand: true,
        onPressed: () => _reopen(task!),
      );
    } else {
      action = NexoButton.secondary(
        label: 'Marcar como concluída',
        leadingIcon: LucideIcons.check,
        expand: true,
        onPressed: () => completeTask(task!),
      );
    }

    return PopScope(
      canPop: !_dirty || leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: bar,
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  spacing.lg,
                  spacing.sm,
                  spacing.lg,
                  spacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: form,
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.lg,
                  spacing.sm,
                  spacing.lg,
                  spacing.xl,
                ),
                child: action,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resumo no topo do detalhe: o ícone da situação (16) e o texto do prazo;
/// atrasada em Error, com a palavra "Atrasada" (a cor não é o único sinal).
class _Summary extends StatelessWidget {
  const _Summary({required this.text, required this.overdue, this.icon});

  final String text;
  final bool overdue;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.nexoColors;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: c.iconSecondary),
          SizedBox(width: context.spacing.sm),
        ],
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium!
                .copyWith(color: overdue ? c.error : c.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

enum _Unit {
  minutes('Minutos', 1),
  hours('Horas', 60),
  days('Dias', 1440);

  const _Unit(this.label, this.factor);

  final String label;
  final int factor;
}

/// Painel "Novo aviso": quanto tempo antes, a unidade e "Aplicar". Até 30
/// dias; aviso repetido não entra. Devolve os minutos.
class _CustomReminderForm extends StatefulWidget {
  const _CustomReminderForm({required this.existing});

  final List<int> existing;

  @override
  State<_CustomReminderForm> createState() => _CustomReminderFormState();
}

class _CustomReminderFormState extends State<_CustomReminderForm> {
  final _amount = TextEditingController();
  _Unit _unit = _Unit.days;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _apply() {
    final amount = int.tryParse(_amount.text) ?? 0;
    final minutes = amount * _unit.factor;
    final String? error;
    if (amount < 1) {
      error = 'Informe quanto tempo antes.';
    } else if (minutes > TaskReminder.maxMinutes) {
      error = 'Escolha até 30 dias antes.';
    } else if (widget.existing.contains(minutes)) {
      error = 'Este aviso já foi adicionado.';
    } else {
      error = null;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NexoTextField(
            label: 'Quanto tempo antes',
            controller: _amount,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            helperText: 'Até 30 dias antes do prazo.',
            errorText: _error,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _apply(),
          ),
          SizedBox(height: spacing.md),
          Semantics(
            label: 'Unidade',
            container: true,
            child: NexoSegmented<_Unit>(
              segments: [
                for (final u in _Unit.values) (value: u, label: u.label),
              ],
              selected: _unit,
              onChanged: (u) => setState(() {
                _unit = u;
                _error = null;
              }),
            ),
          ),
          SizedBox(height: spacing.lg),
          NexoButton.primary(label: 'Aplicar', expand: true, onPressed: _apply),
          SizedBox(height: spacing.lg),
        ],
      ),
    );
  }
}
