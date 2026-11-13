import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/dashboard_stats.dart';
import '../models/enums.dart';

class DomainValidationException implements Exception {
  final String message;
  DomainValidationException(this.message);

  @override
  String toString() => message;
}

class TaskFilterParams {
  final int? projectId;
  final int? assigneeId;
  final TaskStatus? status;
  final TaskPriority? priority;
  final String searchQuery;
  final bool sortByDeadline;
  final bool ascending;
  final int limit;
  final int offset;

  const TaskFilterParams({
    this.projectId,
    this.assigneeId,
    this.status,
    this.priority,
    this.searchQuery = '',
    this.sortByDeadline = false,
    this.ascending = false,
    this.limit = 50,
    this.offset = 0,
  });
}

class TaskFlowRepository {
  final AppDatabase db;

  TaskFlowRepository(this.db);

  // ==================== USERS ====================

  Stream<List<UserRecord>> watchUsers() {
    return (db.select(db.users)..orderBy([(u) => OrderingTerm.asc(u.name)])).watch();
  }

  Future<List<UserRecord>> getAllUsers() => db.select(db.users).get();

  Future<int> createUser({required String name, required String email}) async {
    final trimmedName = name.trim();
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedName.isEmpty || !trimmedEmail.contains('@')) {
      throw DomainValidationException('Укажите корректное имя и email пользователя.');
    }
    final existing = await (db.select(db.users)..where((u) => u.email.equals(trimmedEmail))).getSingleOrNull();
    if (existing != null) {
      throw DomainValidationException('Пользователь с email $trimmedEmail уже существует.');
    }
    return db.into(db.users).insert(
          UsersCompanion.insert(
            name: trimmedName,
            email: trimmedEmail,
          ),
        );
  }

  Future<void> updateUser({required int id, required String name, required String email}) async {
    final trimmedName = name.trim();
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedName.isEmpty || !trimmedEmail.contains('@')) {
      throw DomainValidationException('Некорректные данные пользователя.');
    }
    final existing = await (db.select(db.users)
          ..where((u) => u.email.equals(trimmedEmail) & u.id.equals(id).not()))
        .getSingleOrNull();
    if (existing != null) {
      throw DomainValidationException('Email $trimmedEmail занят другим пользователем.');
    }
    await (db.update(db.users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(name: Value(trimmedName), email: Value(trimmedEmail)),
    );
  }

  Future<void> deleteUser(int userId) async {
    // Запрет удаления, если у пользователя есть незавершённые задачи
    final activeTasks = await (db.select(db.tasks)
          ..where((t) =>
              t.assigneeId.equals(userId) &
              t.deletedAt.isNull() &
              t.status.isNotIn([TaskStatus.done.name, TaskStatus.cancelled.name])))
        .get();

    if (activeTasks.isNotEmpty) {
      throw DomainValidationException(
        'Нельзя удалить пользователя: за ним закреплено незавершённых задач: ${activeTasks.length}.',
      );
    }

    await (db.delete(db.users)..where((u) => u.id.equals(userId))).go();
  }

  // ==================== PROJECTS & MEMBERS ====================

  Stream<List<ProjectRecord>> watchProjects() {
    return (db.select(db.projects)..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).watch();
  }

  Future<int> createProject({
    required String title,
    String description = '',
    ProjectStatus status = ProjectStatus.active,
    DateTime? completedAt,
    int? ownerUserId,
  }) async {
    if (title.trim().isEmpty) {
      throw DomainValidationException('Название проекта не может быть пустым.');
    }
    return db.transaction(() async {
      final projectId = await db.into(db.projects).insert(
            ProjectsCompanion.insert(
              title: title.trim(),
              description: Value(description.trim()),
              status: Value(status),
              completedAt: Value(completedAt),
            ),
          );
      if (ownerUserId != null) {
        await db.into(db.projectMembers).insert(
              ProjectMembersCompanion.insert(
                projectId: projectId,
                userId: ownerUserId,
                role: Value(MemberRole.owner),
              ),
            );
      }
      return projectId;
    });
  }

  Future<void> updateProject({
    required int projectId,
    required String title,
    required String description,
    required ProjectStatus status,
    DateTime? completedAt,
  }) async {
    if (title.trim().isEmpty) {
      throw DomainValidationException('Название проекта не может быть пустым.');
    }
    await (db.update(db.projects)..where((p) => p.id.equals(projectId))).write(
      ProjectsCompanion(
        title: Value(title.trim()),
        description: Value(description.trim()),
        status: Value(status),
        completedAt: Value(completedAt),
      ),
    );
  }

  Future<void> deleteProject(int projectId) async {
    await (db.delete(db.projects)..where((p) => p.id.equals(projectId))).go();
  }

  Stream<List<(ProjectMemberRecord, UserRecord)>> watchProjectMembers(int projectId) {
    final query = db.select(db.projectMembers).join([
      innerJoin(db.users, db.users.id.equalsExp(db.projectMembers.userId)),
    ])
      ..where(db.projectMembers.projectId.equals(projectId));

    return query.watch().map((rows) {
      return rows.map((row) {
        return (row.readTable(db.projectMembers), row.readTable(db.users));
      }).toList();
    });
  }

  Future<void> addProjectMember({
    required int projectId,
    required int userId,
    MemberRole role = MemberRole.member,
  }) async {
    final existing = await (db.select(db.projectMembers)
          ..where((pm) => pm.projectId.equals(projectId) & pm.userId.equals(userId)))
        .getSingleOrNull();
    if (existing != null) {
      throw DomainValidationException('Пользователь уже является участником этого проекта.');
    }
    await db.into(db.projectMembers).insert(
          ProjectMembersCompanion.insert(
            projectId: projectId,
            userId: userId,
            role: Value(role),
          ),
        );
  }

  Future<void> updateMemberRole({
    required int projectId,
    required int userId,
    required MemberRole role,
  }) async {
    await (db.update(db.projectMembers)
          ..where((pm) => pm.projectId.equals(projectId) & pm.userId.equals(userId)))
        .write(ProjectMembersCompanion(role: Value(role)));
  }

  Future<void> removeProjectMember({required int projectId, required int userId}) async {
    await (db.delete(db.projectMembers)
          ..where((pm) => pm.projectId.equals(projectId) & pm.userId.equals(userId)))
        .go();
  }

  // ==================== TASKS & VALIDATIONS ====================

  Future<void> _validateAssigneeInProject(int projectId, int assigneeId) async {
    final member = await (db.select(db.projectMembers)
          ..where((pm) => pm.projectId.equals(projectId) & pm.userId.equals(assigneeId)))
        .getSingleOrNull();
    if (member == null) {
      throw DomainValidationException(
        'Исполнитель должен быть участником данного проекта.',
      );
    }
  }

  Future<void> _validateDailyTaskLimit(int assigneeId, DateTime? deadline, {int? excludeTaskId}) async {
    if (deadline == null) return;
    final dayStart = DateTime(deadline.year, deadline.month, deadline.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final query = db.select(db.tasks)
      ..where((t) {
        Expression<bool> cond = t.assigneeId.equals(assigneeId) &
            t.deletedAt.isNull() &
            t.status.isNotIn([TaskStatus.done.name, TaskStatus.cancelled.name]) &
            t.deadline.isBiggerOrEqualValue(dayStart) &
            t.deadline.isSmallerThanValue(dayEnd);
        if (excludeTaskId != null) {
          cond = cond & t.id.equals(excludeTaskId).not();
        }
        return cond;
      });

    final count = (await query.get()).length;
    if (count >= 3) {
      throw DomainValidationException(
        'Лимит превышен: у исполнителя уже есть 3 незавершённые задачи на эту дату.',
      );
    }
  }

  Future<int> createTask({
    required String title,
    String description = '',
    required int projectId,
    int? assigneeId,
    TaskPriority priority = TaskPriority.medium,
    TaskStatus status = TaskStatus.todo,
    DateTime? deadline,
    int? actorUserId,
    bool simulateHistoryFailure = false,
  }) async {
    if (title.trim().isEmpty) {
      throw DomainValidationException('Название задачи обязательно.');
    }

    final project = await (db.select(db.projects)..where((p) => p.id.equals(projectId))).getSingleOrNull();
    if (project == null) {
      throw DomainValidationException('Нельзя создать задачу без существующего проекта.');
    }

    if (assigneeId != null) {
      await _validateAssigneeInProject(projectId, assigneeId);
      await _validateDailyTaskLimit(assigneeId, deadline);
    }

    // Транзакция: создание задачи + первая запись в историю
    return db.transaction(() async {
      final now = DateTime.now();
      final taskId = await db.into(db.tasks).insert(
            TasksCompanion.insert(
              title: title.trim(),
              description: Value(description.trim()),
              projectId: projectId,
              assigneeId: Value(assigneeId),
              priority: Value(priority),
              status: Value(status),
              deadline: Value(deadline),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      if (simulateHistoryFailure) {
        throw StateError('Simulated history write failure');
      }

      await db.into(db.taskHistory).insert(
            TaskHistoryCompanion.insert(
              taskId: taskId,
              previousStatus: const Value(null),
              newStatus: status.name,
              note: const Value('Задача создана'),
              changedByUserId: Value(actorUserId ?? assigneeId),
              changedAt: Value(now),
            ),
          );

      return taskId;
    });
  }

  Future<void> updateTask({
    required int taskId,
    required String title,
    required String description,
    required TaskPriority priority,
    DateTime? deadline,
  }) async {
    if (title.trim().isEmpty) {
      throw DomainValidationException('Название задачи обязательно.');
    }
    final existing = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (existing == null) {
      throw DomainValidationException('Задача не найдена.');
    }
    if (existing.assigneeId != null) {
      await _validateDailyTaskLimit(existing.assigneeId!, deadline, excludeTaskId: taskId);
    }
    await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        title: Value(title.trim()),
        description: Value(description.trim()),
        priority: Value(priority),
        deadline: Value(deadline),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> changeTaskStatus({
    required int taskId,
    required TaskStatus newStatus,
    int? changedByUserId,
  }) async {
    await db.transaction(() async {
      final task = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
      if (task == null) {
        throw DomainValidationException('Задача не найдена.');
      }
      if (task.status == newStatus) return;

      final now = DateTime.now();
      await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          status: Value(newStatus),
          updatedAt: Value(now),
        ),
      );

      await db.into(db.taskHistory).insert(
            TaskHistoryCompanion.insert(
              taskId: taskId,
              previousStatus: Value(task.status.name),
              newStatus: newStatus.name,
              note: Value('Статус изменён: ${task.status.label} → ${newStatus.label}'),
              changedByUserId: Value(changedByUserId),
              changedAt: Value(now),
            ),
          );
    });
  }

  /// Отмена последнего изменения статуса (Undo)
  Future<void> undoLastStatusChange({required int taskId, int? changedByUserId}) async {
    await db.transaction(() async {
      final task = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
      if (task == null) {
        throw DomainValidationException('Задача не найдена.');
      }

      final lastStatusChange = await (db.select(db.taskHistory)
            ..where((h) => h.taskId.equals(taskId) & h.previousStatus.isNotNull())
            ..orderBy([(h) => OrderingTerm.desc(h.id)])
            ..limit(1))
          .getSingleOrNull();

      if (lastStatusChange == null || lastStatusChange.previousStatus == null) {
        throw DomainValidationException('Нет предыдущего статуса для отмены.');
      }

      final restoredStatus = TaskStatus.values.firstWhere(
        (s) => s.name == lastStatusChange.previousStatus,
        orElse: () => TaskStatus.todo,
      );

      final now = DateTime.now();
      await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          status: Value(restoredStatus),
          updatedAt: Value(now),
        ),
      );

      await db.into(db.taskHistory).insert(
            TaskHistoryCompanion.insert(
              taskId: taskId,
              previousStatus: Value(task.status.name),
              newStatus: restoredStatus.name,
              note: Value('Отмена изменения (Undo): возврат к ${restoredStatus.label}'),
              changedByUserId: Value(changedByUserId),
              changedAt: Value(now),
            ),
          );
    });
  }

  /// Атомарное переназначение исполнителя
  Future<void> reassignTask({
    required int taskId,
    required int? newAssigneeId,
    int? changedByUserId,
  }) async {
    await db.transaction(() async {
      final task = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
      if (task == null) {
        throw DomainValidationException('Задача не найдена.');
      }
      if (newAssigneeId != null) {
        await _validateAssigneeInProject(task.projectId, newAssigneeId);
        await _validateDailyTaskLimit(newAssigneeId, task.deadline, excludeTaskId: taskId);
      }

      final now = DateTime.now();
      await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          assigneeId: Value(newAssigneeId),
          updatedAt: Value(now),
        ),
      );

      await db.into(db.taskHistory).insert(
            TaskHistoryCompanion.insert(
              taskId: taskId,
              previousStatus: Value(task.status.name),
              newStatus: task.status.name,
              note: Value(newAssigneeId == null
                  ? 'Исполнитель снят с задачи'
                  : 'Назначен новый исполнитель (ID: $newAssigneeId)'),
              changedByUserId: Value(changedByUserId),
              changedAt: Value(now),
            ),
          );
    });
  }

  // ==================== SOFT DELETE & TRASH ====================

  Future<void> softDeleteTask(int taskId) async {
    await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  Future<void> restoreTask(int taskId) async {
    await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
      const TasksCompanion(deletedAt: Value(null)),
    );
  }

  Future<void> permanentlyDeleteTask(int taskId) async {
    await (db.delete(db.tasks)..where((t) => t.id.equals(taskId))).go();
  }

  Stream<List<TaskRecord>> watchDeletedTasks() {
    return (db.select(db.tasks)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .watch();
  }

  // ==================== FILTER, SEARCH, PAGINATION & WATCH ====================

  SimpleSelectStatement<$TasksTable, TaskRecord> _buildTaskQuery(TaskFilterParams params) {
    final query = db.select(db.tasks)
      ..where((t) {
        Expression<bool> cond = t.deletedAt.isNull();
        if (params.projectId != null) {
          cond = cond & t.projectId.equals(params.projectId!);
        }
        if (params.assigneeId != null) {
          cond = cond & t.assigneeId.equals(params.assigneeId!);
        }
        if (params.status != null) {
          cond = cond & t.status.equals(params.status!.name);
        }
        if (params.priority != null) {
          cond = cond & t.priority.equals(params.priority!.name);
        }
        if (params.searchQuery.trim().isNotEmpty) {
          final pattern = '%${params.searchQuery.trim()}%';
          cond = cond & (t.title.like(pattern) | t.description.like(pattern));
        }
        return cond;
      });

    query.orderBy([
      (t) {
        final col = params.sortByDeadline ? t.deadline : t.createdAt;
        return params.ascending ? OrderingTerm.asc(col) : OrderingTerm.desc(col);
      }
    ]);

    query.limit(params.limit, offset: params.offset);
    return query;
  }

  Stream<List<TaskRecord>> watchTasks(TaskFilterParams params) {
    return _buildTaskQuery(params).watch();
  }

  Future<List<TaskRecord>> fetchTasks(TaskFilterParams params) {
    return _buildTaskQuery(params).get();
  }

  Stream<List<TaskHistoryRecord>> watchTaskHistory(int taskId) {
    return (db.select(db.taskHistory)
          ..where((h) => h.taskId.equals(taskId))
          ..orderBy([(h) => OrderingTerm.desc(h.id)]))
        .watch();
  }

  // ==================== COMMENTS & ATTACHMENTS ====================

  Future<int> addComment({
    required int taskId,
    required int authorId,
    required String content,
  }) async {
    if (content.trim().isEmpty) {
      throw DomainValidationException('Комментарий не может быть пустым.');
    }
    final task = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null) {
      throw DomainValidationException('Нельзя добавить комментарий к несуществующей задаче.');
    }
    return db.into(db.comments).insert(
          CommentsCompanion.insert(
            content: content.trim(),
            authorId: authorId,
            taskId: taskId,
          ),
        );
  }

  Future<void> deleteComment({required int commentId, required int requesterUserId}) async {
    final comment = await (db.select(db.comments)..where((c) => c.id.equals(commentId))).getSingleOrNull();
    if (comment == null) return;
    if (comment.authorId != requesterUserId) {
      throw DomainValidationException('Удалять комментарий может только его автор.');
    }
    await (db.delete(db.comments)..where((c) => c.id.equals(commentId))).go();
  }

  Stream<List<(CommentRecord, UserRecord)>> watchTaskComments(int taskId) {
    final query = db.select(db.comments).join([
      innerJoin(db.users, db.users.id.equalsExp(db.comments.authorId)),
    ])
      ..where(db.comments.taskId.equals(taskId))
      ..orderBy([OrderingTerm.desc(db.comments.createdAt)]);

    return query.watch().map((rows) {
      return rows.map((r) => (r.readTable(db.comments), r.readTable(db.users))).toList();
    });
  }

  Future<int> addAttachment({
    required int taskId,
    required String fileName,
    required String localPath,
  }) async {
    final task = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null) {
      throw DomainValidationException('Задача не найдена.');
    }
    return db.into(db.attachments).insert(
          AttachmentsCompanion.insert(
            fileName: fileName.trim(),
            localPath: localPath.trim(),
            taskId: taskId,
          ),
        );
  }

  Stream<List<AttachmentRecord>> watchTaskAttachments(int taskId) {
    return (db.select(db.attachments)
          ..where((a) => a.taskId.equals(taskId))
          ..orderBy([(a) => OrderingTerm.desc(a.addedAt)]))
        .watch();
  }

  // ==================== SQL DASHBOARD STATISTICS ====================

  Future<DashboardStats> getDashboardStats() async {
    final projectsCountRow = await db.customSelect('SELECT COUNT(*) AS c FROM projects').getSingle();
    final totalProjects = projectsCountRow.read<int>('c');

    final taskSummaryRow = await db.customSelect('''
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) AS completed,
        SUM(CASE WHEN status NOT IN ('done', 'cancelled') THEN 1 ELSE 0 END) AS incomplete,
        SUM(CASE WHEN deadline IS NOT NULL AND deadline < ? AND status NOT IN ('done', 'cancelled') THEN 1 ELSE 0 END) AS overdue
      FROM tasks
      WHERE deleted_at IS NULL
    ''', variables: [
      Variable.withInt(DateTime.now().millisecondsSinceEpoch ~/ 1000),
    ]).getSingle();

    final totalTasks = taskSummaryRow.read<int>('total');
    final completedTasks = taskSummaryRow.readNullable<int>('completed') ?? 0;
    final incompleteTasks = taskSummaryRow.readNullable<int>('incomplete') ?? 0;
    final overdueTasks = taskSummaryRow.readNullable<int>('overdue') ?? 0;

    final priorityRows = await db.customSelect('''
      SELECT priority, COUNT(*) AS c
      FROM tasks
      WHERE deleted_at IS NULL
      GROUP BY priority
    ''').get();

    final tasksByPriority = {for (var p in TaskPriority.values) p: 0};
    for (final row in priorityRows) {
      final pName = row.read<String>('priority');
      final pEnum = TaskPriority.values.firstWhere(
        (e) => e.name == pName,
        orElse: () => TaskPriority.medium,
      );
      tasksByPriority[pEnum] = row.read<int>('c');
    }

    final assigneeRows = await db.customSelect('''
      SELECT u.id, u.name, COUNT(t.id) AS c
      FROM users u
      LEFT JOIN tasks t ON t.assignee_id = u.id AND t.deleted_at IS NULL
      GROUP BY u.id, u.name
      ORDER BY c DESC
    ''').get();

    final tasksByAssignee = assigneeRows
        .map((r) => AssigneeWorkloadItem(
              userId: r.read<int>('id'),
              userName: r.read<String>('name'),
              taskCount: r.read<int>('c'),
            ))
        .toList();

    final projectRows = await db.customSelect('''
      SELECT
        p.id,
        p.title,
        COUNT(t.id) AS total,
        SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END) AS completed
      FROM projects p
      LEFT JOIN tasks t ON t.project_id = p.id AND t.deleted_at IS NULL
      GROUP BY p.id, p.title
      ORDER BY p.id DESC
    ''').get();

    final projectProgress = projectRows
        .map((r) => ProjectProgressItem(
              projectId: r.read<int>('id'),
              projectTitle: r.read<String>('title'),
              totalTasks: r.read<int>('total'),
              completedTasks: r.readNullable<int>('completed') ?? 0,
            ))
        .toList();

    return DashboardStats(
      totalProjects: totalProjects,
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      incompleteTasks: incompleteTasks,
      overdueTasks: overdueTasks,
      tasksByPriority: tasksByPriority,
      tasksByAssignee: tasksByAssignee,
      projectProgress: projectProgress,
    );
  }
}
