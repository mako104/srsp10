import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../models/enums.dart';
import '../repositories/taskflow_repository.dart';
import '../state/taskflow_provider.dart';
import 'task_detail_screen.dart';

class ProjectDetailScreen extends StatelessWidget {
  final ProjectRecord project;
  const ProjectDetailScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskFlowProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(project.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await provider.repository.deleteProject(project.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Статус: ${project.status.label}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(project.description.isEmpty ? 'Описание отсутствует' : project.description),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Участники проекта', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              TextButton.icon(
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Добавить'),
                onPressed: () => _showAddMemberDialog(context),
              ),
            ],
          ),
          StreamBuilder<List<(ProjectMemberRecord, UserRecord)>>(
            stream: provider.repository.watchProjectMembers(project.id),
            builder: (context, snapshot) {
              final members = snapshot.data ?? [];
              if (members.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Нет добавленных участников'),
                );
              }
              return Column(
                children: members.map((item) {
                  final (member, user) = item;
                  return Card(
                    child: ListTile(
                      title: Text(user.name),
                      subtitle: Text('${user.email} • Роль: ${member.role.label}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => provider.repository.removeProjectMember(
                          projectId: project.id,
                          userId: user.id,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Задачи проекта', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              TextButton.icon(
                icon: const Icon(Icons.add_task),
                label: const Text('Новая задача'),
                onPressed: () => _showCreateTaskDialog(context),
              ),
            ],
          ),
          StreamBuilder<List<TaskRecord>>(
            stream: provider.repository.watchTasks(TaskFilterParams(projectId: project.id)),
            builder: (context, snapshot) {
              final tasks = snapshot.data ?? [];
              if (tasks.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('В проекте пока нет задач'),
                );
              }
              return Column(
                children: tasks.map((task) {
                  return Card(
                    child: ListTile(
                      title: Text(task.title),
                      subtitle: Text('${task.status.label} • Приоритет: ${task.priority.label}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
                        );
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMemberDialog(BuildContext context) async {
    final provider = context.read<TaskFlowProvider>();
    final allUsers = await provider.repository.getAllUsers();
    if (!context.mounted) return;
    if (allUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала создайте пользователей во вкладке "Участники"')),
      );
      return;
    }

    int selectedUserId = allUsers.first.id;
    MemberRole selectedRole = MemberRole.member;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Добавить участника'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedUserId,
                decoration: const InputDecoration(labelText: 'Пользователь'),
                items: allUsers.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
                onChanged: (v) => setState(() => selectedUserId = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MemberRole>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Роль'),
                items: MemberRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                onChanged: (v) => setState(() => selectedRole = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              onPressed: () async {
                try {
                  await provider.repository.addProjectMember(
                    projectId: project.id,
                    userId: selectedUserId,
                    role: selectedRole,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } on DomainValidationException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateTaskDialog(BuildContext context) async {
    final provider = context.read<TaskFlowProvider>();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    TaskPriority priority = TaskPriority.medium;
    DateTime? deadline;
    int? assigneeId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Создать задачу'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Название')),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Описание')),
                const SizedBox(height: 10),
                DropdownButtonFormField<TaskPriority>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Приоритет'),
                  items: TaskPriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
                  onChanged: (v) => setState(() => priority = v!),
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<(ProjectMemberRecord, UserRecord)>>(
                  stream: provider.repository.watchProjectMembers(project.id),
                  builder: (context, snapshot) {
                    final members = snapshot.data ?? [];
                    return DropdownButtonFormField<int?>(
                      value: assigneeId,
                      decoration: const InputDecoration(labelText: 'Исполнитель (участник проекта)'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Не назначен')),
                        ...members.map((m) => DropdownMenuItem<int?>(value: m.$2.id, child: Text(m.$2.name))),
                      ],
                      onChanged: (v) => setState(() => assigneeId = v),
                    );
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(deadline == null
                      ? 'Дедлайн не выбран'
                      : 'Дедлайн: ${deadline!.toLocal().toString().split(' ').first}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => deadline = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              onPressed: () async {
                try {
                  await provider.repository.createTask(
                    title: titleCtrl.text,
                    description: descCtrl.text,
                    projectId: project.id,
                    assigneeId: assigneeId,
                    priority: priority,
                    deadline: deadline,
                    actorUserId: provider.activeUserId,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } on DomainValidationException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }
}
