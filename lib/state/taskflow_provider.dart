import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../database/benchmark_helper.dart';
import '../models/dashboard_stats.dart';
import '../models/enums.dart';
import '../repositories/taskflow_repository.dart';

class TaskFlowProvider extends ChangeNotifier {
  final TaskFlowRepository repository;
  final AppDatabase database;

  TaskFlowProvider({required this.repository, required this.database});

  int? _activeUserId;
  int? get activeUserId => _activeUserId;

  TaskFilterParams _filter = const TaskFilterParams();
  TaskFilterParams get filter => _filter;

  void setActiveUser(int? userId) {
    _activeUserId = userId;
    notifyListeners();
  }

  void updateFilter(TaskFilterParams newFilter) {
    _filter = newFilter;
    notifyListeners();
  }

  void nextPage() {
    _filter = TaskFilterParams(
      projectId: _filter.projectId,
      assigneeId: _filter.assigneeId,
      status: _filter.status,
      priority: _filter.priority,
      searchQuery: _filter.searchQuery,
      sortByDeadline: _filter.sortByDeadline,
      ascending: _filter.ascending,
      limit: _filter.limit,
      offset: _filter.offset + _filter.limit,
    );
    notifyListeners();
  }

  void prevPage() {
    final nextOffset = (_filter.offset - _filter.limit).clamp(0, 1000000);
    _filter = TaskFilterParams(
      projectId: _filter.projectId,
      assigneeId: _filter.assigneeId,
      status: _filter.status,
      priority: _filter.priority,
      searchQuery: _filter.searchQuery,
      sortByDeadline: _filter.sortByDeadline,
      ascending: _filter.ascending,
      limit: _filter.limit,
      offset: nextOffset,
    );
    notifyListeners();
  }

  Future<DashboardStats> loadStats() => repository.getDashboardStats();

  Future<BenchmarkResult> runBenchmark() => BenchmarkHelper.runPerformanceComparison(database);
}
