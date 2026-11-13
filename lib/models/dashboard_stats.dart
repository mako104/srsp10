import 'enums.dart';

class ProjectProgressItem {
  final int projectId;
  final String projectTitle;
  final int totalTasks;
  final int completedTasks;

  ProjectProgressItem({
    required this.projectId,
    required this.projectTitle,
    required this.totalTasks,
    required this.completedTasks,
  });

  double get percentage => totalTasks == 0 ? 0.0 : (completedTasks / totalTasks) * 100;
}

class AssigneeWorkloadItem {
  final int userId;
  final String userName;
  final int taskCount;

  AssigneeWorkloadItem({
    required this.userId,
    required this.userName,
    required this.taskCount,
  });
}

class DashboardStats {
  final int totalProjects;
  final int totalTasks;
  final int completedTasks;
  final int incompleteTasks;
  final int overdueTasks;
  final Map<TaskPriority, int> tasksByPriority;
  final List<AssigneeWorkloadItem> tasksByAssignee;
  final List<ProjectProgressItem> projectProgress;

  DashboardStats({
    required this.totalProjects,
    required this.totalTasks,
    required this.completedTasks,
    required this.incompleteTasks,
    required this.overdueTasks,
    required this.tasksByPriority,
    required this.tasksByAssignee,
    required this.projectProgress,
  });
}
