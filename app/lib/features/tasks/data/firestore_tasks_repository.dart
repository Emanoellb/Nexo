import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firestore_access.dart';
import '../domain/task.dart';
import '../domain/task_rules.dart';
import 'tasks_repository.dart';

/// `users/{uid}/tasks` no Firestore (regras v0.9):
/// - `completedAt` vai em toda criação (`null` se pendente) e é o carimbo do
///   servidor ao concluir;
/// - a situação da entrega fica coerente com a conclusão no mesmo gravar;
/// - editar não mexe em `completed` nem em `completedAt` (só o concluir e o
///   reabrir), para o carimbo não mudar sem querer.
///
/// As gravações não esperam o servidor ([FirestoreAccess.send]).
class FirestoreTasksRepository implements TasksRepository {
  FirestoreTasksRepository(
    this._access, {
    required String? uid,
    required this.clock,
  }) : _user = UserDocs(uid);

  final FirestoreAccess _access;
  final UserDocs _user;

  /// Para a situação da entrega ao concluir (o carimbo é do servidor).
  final DateTime Function() clock;

  CollectionReference<Map<String, dynamic>> _tasks(FirebaseFirestore db) =>
      _user.collection(db, 'tasks');

  @override
  Stream<List<NexoTask>> watchTasks() {
    if (!_user.signedIn) return Stream.value(const []);
    return _access
        .watchDocs(_tasks)
        .map(
          (docs) =>
              [for (final doc in docs) ?taskFromFirestore(doc.id, doc.data())]
                ..sort(compareTasksByDue),
        );
  }

  /// A tarefa como o aparelho a conhece agora (o cache primeiro).
  Future<NexoTask?> _current(String taskId) => _access.run((db) async {
    final snapshot = await _tasks(db).doc(taskId).snapshots().first;
    return taskFromFirestore(snapshot.id, snapshot.data());
  });

  @override
  Future<NexoTask> createTask(NexoTask draft) async {
    late NexoTask task;
    await _access.send((db) {
      final ref = _tasks(db).doc();
      // O rascunho já vem coerente (conclusão × entrega); a hora real da
      // conclusão é o carimbo do servidor.
      task = NexoTask(
        id: ref.id,
        title: draft.title,
        priority: draft.priority,
        completed: draft.completed,
        completedAt: draft.completed ? clock() : null,
        subjectId: draft.subjectId,
        dueAt: draft.dueAt,
        remindersMinutesBefore: draft.remindersMinutesBefore,
        deliveryStatus: draft.deliveryStatus,
      );
      return ref.set({
        ...taskToFirestore(task),
        'completed': task.completed,
        'completedAt': task.completed ? FieldValue.serverTimestamp() : null,
        ...createdStamps(),
      });
    });
    return task;
  }

  @override
  Future<void> updateTask(NexoTask task) => _access.send(
    (db) =>
        _tasks(db)
            .doc(task.id)
            .update({...taskToFirestore(task), ...updatedStamp()}),
  );

  @override
  Future<int> setCompleted(String taskId, bool completed) async {
    final task = await _current(taskId);
    if (task == null) throw StateError('Tarefa $taskId não existe.');
    final next = task.withCompleted(completed, now: clock());
    if (next.completed != task.completed) {
      await _access.send(
        (db) => _tasks(db).doc(taskId).update({
          'completed': next.completed,
          'completedAt': next.completed ? FieldValue.serverTimestamp() : null,
          'deliveryStatus': next.deliveryStatus?.value,
          ...updatedStamp(),
        }),
      );
    }
    return taskPointsDelta(
      wasCompleted: task.completed,
      isCompleted: completed,
    );
  }

  @override
  Future<int> deleteTask(String taskId) async {
    final task = await _current(taskId);
    if (task == null) return 0;
    await _access.send((db) => _tasks(db).doc(taskId).delete());
    return taskPointsDelta(wasCompleted: task.completed, isCompleted: false);
  }
}

/// Campos editáveis da tarefa (sem `completed` e `completedAt`, que só o
/// concluir e o reabrir gravam).
Map<String, Object?> taskToFirestore(NexoTask task) => {
  'title': task.title,
  'priority': task.priority.value,
  'subjectId': task.subjectId,
  'dueAt': task.dueAt == null ? null : Timestamp.fromDate(task.dueAt!),
  'remindersMinutesBefore': task.remindersMinutesBefore,
  'deliveryStatus': task.deliveryStatus?.value,
};

/// `tasks/{id}` → [NexoTask]; `null` se o documento não existe ou não
/// passa nas regras do app (não quebra a lista).
NexoTask? taskFromFirestore(String id, Map<String, dynamic>? data) {
  if (data == null) return null;
  try {
    final reminders = data['remindersMinutesBefore'];
    // Tarefa de antes da v0.9: um aviso só, em reminderMinutesBefore.
    final legacy = intField(data['reminderMinutesBefore']);
    final subjectId = data['subjectId'];
    return NexoTask(
      id: id,
      title: data['title'] as String,
      priority:
          TaskPriority.values
              .where((p) => p.value == data['priority'])
              .firstOrNull ??
          TaskPriority.none,
      completed: data['completed'] == true,
      completedAt: timestampField(data['completedAt']),
      subjectId: subjectId is String ? subjectId : null,
      dueAt: timestampField(data['dueAt']),
      remindersMinutesBefore: reminders is List
          ? [for (final r in reminders) ?intField(r)]
          : [?legacy],
      deliveryStatus: DeliveryStatus.fromValue(
        data['deliveryStatus'] as String?,
      ),
    );
  } on Object {
    return null;
  }
}
