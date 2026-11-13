import 'package:drift/drift.dart';
import '../models/enums.dart';
import 'app_database.dart';

class BenchmarkResult {
  final Duration insertDuration;
  final Duration indexedQueryDuration;
  final Duration unindexedQueryDuration;
  final int matchedRows;

  BenchmarkResult({
    required this.insertDuration,
    required this.indexedQueryDuration,
    required this.unindexedQueryDuration,
    required this.matchedRows,
  });
}

class BenchmarkHelper {
  static Future<BenchmarkResult> runPerformanceComparison(AppDatabase db) async {
    final swInsert = Stopwatch()..start();

    await db.batch((batch) {
      batch.insertAll(
        db.users,
        List.generate(
          1000,
          (i) => UsersCompanion.insert(
            name: 'User $i',
            email: 'bench_user_$i@taskflow.local',
          ),
        ),
        mode: InsertMode.insertOrIgnore,
      );

      batch.insertAll(
        db.projects,
        List.generate(
          100,
          (i) => ProjectsCompanion.insert(
            title: 'Project $i',
            description: Value('Benchmark project #$i'),
          ),
        ),
      );
    });

    final users = await db.select(db.users).get();
    final projects = await db.select(db.projects).get();

    await db.batch((batch) {
      batch.insertAll(
        db.tasks,
        List.generate(10000, (i) {
          final proj = projects[i % projects.length];
          final user = users[i % users.length];
          final priority = TaskPriority.values[i % TaskPriority.values.length];
          final status = TaskStatus.values[i % TaskStatus.values.length];
          return TasksCompanion.insert(
            title: 'Benchmark Task #$i',
            description: Value('Generated description for task $i'),
            projectId: proj.id,
            assigneeId: Value(user.id),
            priority: Value(priority),
            status: Value(status),
            deadline: Value(DateTime.now().add(Duration(days: (i % 30) - 10))),
          );
        }),
      );
    });
    swInsert.stop();

    // 1. Запрос С индексами
    final swIndexed = Stopwatch()..start();
    final indexedRes = await (db.select(db.tasks)
          ..where((t) =>
              t.projectId.equals(projects.first.id) &
              t.status.equals(TaskStatus.inProgress.name) &
              t.deletedAt.isNull()))
        .get();
    swIndexed.stop();

    // 2. Временно удаляем индекс и выполняем аналогичный поиск без индекса
    await db.customStatement('DROP INDEX IF EXISTS idx_tasks_project_id');
    await db.customStatement('DROP INDEX IF EXISTS idx_tasks_status_priority');

    final swUnindexed = Stopwatch()..start();
    await (db.select(db.tasks)
          ..where((t) =>
              t.projectId.equals(projects.first.id) &
              t.status.equals(TaskStatus.inProgress.name) &
              t.deletedAt.isNull()))
        .get();
    swUnindexed.stop();

    // Восстанавливаем индексы
    await db.customStatement('CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks (project_id)');
    await db.customStatement('CREATE INDEX IF NOT EXISTS idx_tasks_status_priority ON tasks (status, priority)');

    return BenchmarkResult(
      insertDuration: swInsert.elapsed,
      indexedQueryDuration: swIndexed.elapsed,
      unindexedQueryDuration: swUnindexed.elapsed,
      matchedRows: indexedRes.length,
    );
  }
}
