import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/enums.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Users,
  Projects,
  ProjectMembers,
  Tasks,
  Comments,
  Attachments,
  TaskHistory,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Миграция с v1 на v2: добавление поля priority со значением 'medium' по умолчанию
        if (from < 2) {
          await m.addColumn(tasks, tasks.priority);
          await customStatement(
            "UPDATE tasks SET priority = 'medium' WHERE priority IS NULL OR priority = ''",
          );
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'taskflow_srs10.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
