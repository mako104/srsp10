import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow_srs10/database/app_database.dart';
import 'package:taskflow_srs10/models/enums.dart';
import 'package:taskflow_srs10/repositories/taskflow_repository.dart';

void main() {
  late AppDatabase db;
  late TaskFlowRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TaskFlowRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('1. Создание и удаление пользователя без активных задач', () async {
    final userId = await repo.createUser(name: 'Алия', email: 'aliya@example.com');
    final users = await repo.getAllUsers();
    expect(users.length, 1);

    await repo.deleteUser(userId);
    expect(await repo.getAllUsers(), isEmpty);
  });

  test('2. Проверка уникальности email пользователя', () async {
    await repo.createUser(name: 'Алия', email: 'aliya@example.com');
    expect(
      () => repo.createUser(name: 'Дубликат', email: 'ALIYA@example.com'),
      throwsA(isA<DomainValidationException>()),
    );
  });

  test('3. Запрет удаления пользователя с незавершёнными задачами', () async {
    final uId = await repo.createUser(name: 'Алия', email: 'u1@example.com');
    final pId = await repo.createProject(title: 'Проект А', ownerUserId: uId);
    await repo.createTask(title: 'Активная задача', projectId: pId, assigneeId: uId);

    expect(
      () => repo.deleteUser(uId),
      throwsA(isA<DomainValidationException>()),
    );
  });

  test('4. Создание проекта и добавление участников с ролями', () async {
    final u1 = await repo.createUser(name: 'Владелец', email: 'owner@example.com');
    final u2 = await repo.createUser(name: 'Разработчик', email: 'dev@example.com');
    final pId = await repo.createProject(title: 'TaskFlow Mobile', ownerUserId: u1);

    await repo.addProjectMember(projectId: pId, userId: u2, role: MemberRole.admin);
    final members = await repo.watchProjectMembers(pId).first;
    expect(members.length, 2);
  });

  test('5. Запрет повторного добавления одного пользователя в проект', () async {
    final u1 = await repo.createUser(name: 'Алия', email: 'u1@example.com');
    final pId = await repo.createProject(title: 'Проект', ownerUserId: u1);

    expect(
      () => repo.addProjectMember(projectId: pId, userId: u1),
      throwsA(isA<DomainValidationException>()),
    );
  });

  test('6. Создание задачи и проверка принадлежности исполнителя проекту', () async {
    final u1 = await repo.createUser(name: 'Участник', email: 'in@example.com');
    final outsider = await repo.createUser(name: 'Посторонний', email: 'out@example.com');
    final pId = await repo.createProject(title: 'Проект', ownerUserId: u1);

    expect(
      () => repo.createTask(title: 'Задача', projectId: pId, assigneeId: outsider),
      throwsA(isA<DomainValidationException>()),
    );

    final taskId = await repo.createTask(title: 'Валидная задача', projectId: pId, assigneeId: u1);
    expect(taskId, greaterThan(0));
  });

  test('7. Запрет создания задачи для несуществующего проекта', () async {
    expect(
      () => repo.createTask(title: 'Сирота', projectId: 9999),
      throwsA(isA<DomainValidationException>()),
    );
  });

  test('8. Изменение статуса задачи и автоматическое сохранение истории', () async {
    final u1 = await repo.createUser(name: 'Алия', email: 'u1@example.com');
    final pId = await repo.createProject(title: 'Проект', ownerUserId: u1);
    final tId = await repo.createTask(title: 'Задача 1', projectId: pId, assigneeId: u1);

    await repo.changeTaskStatus(taskId: tId, newStatus: TaskStatus.inProgress, changedByUserId: u1);
    final history = await repo.watchTaskHistory(tId).first;

    expect(history.length, 2);
    expect(history.first.previousStatus, TaskStatus.todo.name);
    expect(history.first.newStatus, TaskStatus.inProgress.name);
  });

  test('9. Отмена последнего изменения статуса (Undo)', () async {
    final u1 = await repo.createUser(name: 'Алия', email: 'u1@example.com');
    final pId = await repo.createProject(title: 'Проект', ownerUserId: u1);
    final tId = await repo.createTask(title: 'Задача Undo', projectId: pId, assigneeId: u1);

    await repo.changeTaskStatus(taskId: tId, newStatus: TaskStatus.inProgress);
    await repo.undoLastStatusChange(taskId: tId);

    final tasks = await repo.fetchTasks(TaskFilterParams(projectId: pId));
    expect(tasks.first.status, TaskStatus.todo);
  });

  test('10. Откат транзакции при ошибке записи истории создания задачи', () async {
    final u1 = await repo.createUser(name: 'Алия', email: 'u1@example.com');
    final pId = await repo.createProject(title: 'Проект', ownerUserId: u1);

    await expectLater(
      repo.createTask(
        title: 'Транзакционная задача',
        projectId: pId,
        simulateHistoryFailure: true,
      ),
      throwsStateError,
    );

    final tasks = await repo.fetchTasks(TaskFilterParams(projectId: pId));
    expect(tasks, isEmpty);
  });

  test('11. Ограничение: не более 3 незавершённых задач на один дедлайн', () async {
    final u1 = await repo.createUser(name: 'Алия', email: 'u1@example.com');
    final pId = await repo.createProject(title: 'Проект', ownerUserId: u1);
    final deadline = DateTime(2026, 11, 20, 18, 0);

    for (int i = 1; i <= 3; i++) {
      await repo.createTask(title: 'Task $i', projectId: pId, assigneeId: u1, deadline: deadline);
    }

    expect(
      () => repo.createTask(title: 'Task 4', projectId: pId, assigneeId: u1, deadline: deadline),
      throwsA(isA<DomainValidationException>()),
    );
  });

  test('12. Добавление комментариев и проверка авторства при удалении', () async {
    final u1 = await repo.createUser(name: 'Автор', email: 'a@example.com');
    final u2 = await repo.createUser(name: 'Другой', email: 'b@example.com');
    final pId = await repo.createProject(title: 'Проект', ownerUserId: u1);
    final tId = await repo.createTask(title: 'Задача', projectId: pId);

    final cId = await repo.addComment(taskId: tId, authorId: u1, content: 'Мой комментарий');
    expect(
      () => repo.deleteComment(commentId: cId, requesterUserId: u2),
      throwsA(isA<DomainValidationException>()),
    );

    await repo.deleteComment(commentId: cId, requesterUserId: u1);
    final comments = await repo.watchTaskComments(tId).first;
    expect(comments, isEmpty);
  });

  test('13. Soft Delete и восстановление задачи из корзины', () async {
    final u1 = await repo.createUser(name: 'Алия', email: 'u1@example.com');
    final pId = await repo.createProject(title: 'Проект', ownerUserId: u1);
    final tId = await repo.createTask(title: 'Удаляемая задача', projectId: pId);

    await repo.softDeleteTask(tId);
    expect(await repo.fetchTasks(TaskFilterParams(projectId: pId)), isEmpty);
    expect((await repo.watchDeletedTasks().first).length, 1);

    await repo.restoreTask(tId);
    expect((await repo.fetchTasks(TaskFilterParams(projectId: pId))).length, 1);
  });

  test('14. Корректность расчёта SQL-статистики Dashboard', () async {
    final u1 = await repo.createUser(name: 'Алия', email: 'u1@example.com');
    final pId = await repo.createProject(title: 'Проект 1', ownerUserId: u1);
    final t1 = await repo.createTask(title: 'T1', projectId: pId, assigneeId: u1, priority: TaskPriority.high);
    await repo.createTask(
      title: 'T2',
      projectId: pId,
      assigneeId: u1,
      deadline: DateTime.now().subtract(const Duration(days: 2)),
    );
    await repo.changeTaskStatus(taskId: t1, newStatus: TaskStatus.done);

    final stats = await repo.getDashboardStats();
    expect(stats.totalProjects, 1);
    expect(stats.totalTasks, 2);
    expect(stats.completedTasks, 1);
    expect(stats.overdueTasks, 1);
    expect(stats.projectProgress.first.percentage, 50.0);
  });

  test('15. Фильтрация и поиск задач по названию и приоритету', () async {
    final pId = await repo.createProject(title: 'Поиск');
    await repo.createTask(title: 'Дизайн розовый', projectId: pId, priority: TaskPriority.high);
    await repo.createTask(title: 'База данных', projectId: pId, priority: TaskPriority.low);

    final found = await repo.fetchTasks(const TaskFilterParams(
      searchQuery: 'розовый',
      priority: TaskPriority.high,
    ));
    expect(found.length, 1);
    expect(found.first.title, 'Дизайн розовый');
  });

  test('16. Проверка миграции БД с v1 на v2 (priority = medium по умолчанию)', () async {
    final rawExecutor = NativeDatabase.memory(setup: (rawDb) {
      rawDb.execute('''
        CREATE TABLE projects (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL DEFAULT 0,
          completed_at INTEGER,
          status TEXT NOT NULL DEFAULT 'active'
        );
      ''');
      rawDb.execute('''
        CREATE TABLE tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT NOT NULL DEFAULT '',
          project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
          assignee_id INTEGER,
          status TEXT NOT NULL DEFAULT 'todo',
          deadline INTEGER,
          created_at INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL DEFAULT 0,
          deleted_at INTEGER
        );
      ''');
      rawDb.execute("INSERT INTO projects (id, title) VALUES (1, 'Legacy Project');");
      rawDb.execute("INSERT INTO tasks (id, title, project_id) VALUES (1, 'Legacy Task', 1);");
      rawDb.execute('PRAGMA user_version = 1;');
    });

    final migratedDb = AppDatabase(rawExecutor);
    final migratedTasks = await migratedDb.select(migratedDb.tasks).get();
    expect(migratedTasks.length, 1);
    expect(migratedTasks.first.priority, TaskPriority.medium);
    await migratedDb.close();
  });
}
