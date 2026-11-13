import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../models/enums.dart';
import '../repositories/taskflow_repository.dart';
import '../state/taskflow_provider.dart';
import 'task_detail_screen.dart';

class TasksTab extends StatelessWidget {
  const TasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskFlowProvider>();
    final f = provider.filter;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Поиск по названию и описанию...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (val) {
                  provider.updateFilter(TaskFilterParams(
                    projectId: f.projectId,
                    assigneeId: f.assigneeId,
                    status: f.status,
                    priority: f.priority,
                    searchQuery: val,
                    sortByDeadline: f.sortByDeadline,
                    ascending: f.ascending,
                    limit: f.limit,
                    offset: 0,
                  ));
                },
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    DropdownButton<TaskStatus?>(
                      value: f.status,
                      hint: const Text('Статус'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Все статусы')),
                        ...TaskStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))),
                      ],
                      onChanged: (v) => provider.updateFilter(TaskFilterParams(
                        projectId: f.projectId,
                        assigneeId: f.assigneeId,
                        status: v,
                        priority: f.priority,
                        searchQuery: f.searchQuery,
                        sortByDeadline: f.sortByDeadline,
                        ascending: f.ascending,
                      )),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<TaskPriority?>(
                      value: f.priority,
                      hint: const Text('Приоритет'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Все приоритеты')),
                        ...TaskPriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))),
                      ],
                      onChanged: (v) => provider.updateFilter(TaskFilterParams(
                        projectId: f.projectId,
                        assigneeId: f.assigneeId,
                        status: f.status,
                        priority: v,
                        searchQuery: f.searchQuery,
                        sortByDeadline: f.sortByDeadline,
                        ascending: f.ascending,
                      )),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: Text(f.sortByDeadline ? 'Сорт: Дедлайн' : 'Сорт: Дата создания'),
                      selected: f.sortByDeadline,
                      onSelected: (v) => provider.updateFilter(TaskFilterParams(
                        projectId: f.projectId,
                        assigneeId: f.assigneeId,
                        status: f.status,
                        priority: f.priority,
                        searchQuery: f.searchQuery,
                        sortByDeadline: v,
                        ascending: f.ascending,
                      )),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<TaskRecord>>(
            stream: provider.repository.watchTasks(f),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final tasks = snapshot.data!;
              if (tasks.isEmpty) {
                return const Center(child: Text('Задачи не найдены'));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return Card(
                    child: ListTile(
                      title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${task.status.label} • Приоритет: ${task.priority.label}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'В корзину',
                        onPressed: () => provider.repository.softDeleteTask(task.id),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: f.offset > 0 ? provider.prevPage : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Смещение: ${f.offset} (по ${f.limit})'),
              IconButton(
                onPressed: provider.nextPage,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
