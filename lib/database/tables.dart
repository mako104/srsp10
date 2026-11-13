import 'package:drift/drift.dart';
import '../models/enums.dart';

@DataClassName('UserRecord')
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get email => text().unique().withLength(min: 3, max: 150)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ProjectRecord')
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 150)();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get status => textEnum<ProjectStatus>().withDefault(Constant(ProjectStatus.active.name))();
}

@DataClassName('ProjectMemberRecord')
class ProjectMembers extends Table {
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get userId => integer().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => textEnum<MemberRole>().withDefault(Constant(MemberRole.member.name))();
  DateTimeColumn get joinedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {projectId, userId};
}

@TableIndex(name: 'idx_tasks_project_id', columns: {#projectId})
@TableIndex(name: 'idx_tasks_assignee_id', columns: {#assigneeId})
@TableIndex(name: 'idx_tasks_status_priority', columns: {#status, #priority})
@TableIndex(name: 'idx_tasks_deadline', columns: {#deadline})
@TableIndex(name: 'idx_tasks_deleted_at', columns: {#deletedAt})
@DataClassName('TaskRecord')
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get assigneeId => integer().nullable().references(Users, #id, onDelete: KeyAction.setNull)();
  TextColumn get priority => textEnum<TaskPriority>().withDefault(Constant(TaskPriority.medium.name))();
  TextColumn get status => textEnum<TaskStatus>().withDefault(Constant(TaskStatus.todo.name))();
  DateTimeColumn get deadline => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@DataClassName('CommentRecord')
class Comments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text().withLength(min: 1, max: 2000)();
  IntColumn get authorId => integer().references(Users, #id, onDelete: KeyAction.cascade)();
  IntColumn get taskId => integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('AttachmentRecord')
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fileName => text().withLength(min: 1, max: 255)();
  TextColumn get localPath => text().withLength(min: 1, max: 1000)();
  IntColumn get taskId => integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'idx_history_task_id', columns: {#taskId})
@DataClassName('TaskHistoryRecord')
class TaskHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get previousStatus => text().nullable()();
  TextColumn get newStatus => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get changedByUserId => integer().nullable().references(Users, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get changedAt => dateTime().withDefault(currentDateAndTime)();
}
