import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../models/enums.dart';
import '../repositories/taskflow_repository.dart';
import '../state/taskflow_provider.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskRecord task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _commentCtrl = TextEditingController();
  final _fileNameCtrl = TextEditingController();
  final _filePathCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskFlowProvider>();
    final task = widget.task;

    return Scaffold(
      appBar: AppBar(
        title: Text(task.title),
        actions: [
          IconButton(
            tooltip: 'Отменить последнее изменение статуса (Undo)',
            icon: const Icon(Icons.undo),
            onPressed: () async {
              try {
                await provider.repository.undoLastStatusChange(
                  taskId: task.id,
                  changedByUserId: provider.activeUserId,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Статус восстановлен')),
                  );
                }
              } on DomainValidationException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.description.isEmpty ? 'Без описания' : task.description),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: TaskStatus.values.map((st) {
                      return ChoiceChip(
                        label: Text(st.label),
                        selected: task.status == st,
                        onSelected: (_) async {
                          await provider.repository.changeTaskStatus(
                            taskId: task.id,
                            newStatus: st,
                            changedByUserId: provider.activeUserId,
                          );
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Вложения (локальные пути)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fileNameCtrl,
                  decoration: const InputDecoration(hintText: 'Имя файла (report.pdf)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _filePathCtrl,
                  decoration: const InputDecoration(hintText: 'Путь (/docs/report.pdf)'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: () async {
                  if (_fileNameCtrl.text.trim().isEmpty || _filePathCtrl.text.trim().isEmpty) return;
                  await provider.repository.addAttachment(
                    taskId: task.id,
                    fileName: _fileNameCtrl.text,
                    localPath: _filePathCtrl.text,
                  );
                  _fileNameCtrl.clear();
                  _filePathCtrl.clear();
                },
              ),
            ],
          ),
          StreamBuilder<List<AttachmentRecord>>(
            stream: provider.repository.watchTaskAttachments(task.id),
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              return Column(
                children: items
                    .map((a) => ListTile(
                          leading: const Icon(Icons.insert_drive_file_outlined),
                          title: Text(a.fileName),
                          subtitle: Text(a.localPath),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('Комментарии', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  decoration: const InputDecoration(hintText: 'Написать комментарий...'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () async {
                  final authorId = provider.activeUserId;
                  if (authorId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Выберите активного пользователя в шапке')),
                    );
                    return;
                  }
                  try {
                    await provider.repository.addComment(
                      taskId: task.id,
                      authorId: authorId,
                      content: _commentCtrl.text,
                    );
                    _commentCtrl.clear();
                  } on DomainValidationException catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  }
                },
              ),
            ],
          ),
          StreamBuilder<List<(CommentRecord, UserRecord)>>(
            stream: provider.repository.watchTaskComments(task.id),
            builder: (context, snapshot) {
              final comments = snapshot.data ?? [];
              return Column(
                children: comments.map((item) {
                  final (c, user) = item;
                  return Card(
                    child: ListTile(
                      title: Text(c.content),
                      subtitle: Text('Автор: ${user.name}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          try {
                            await provider.repository.deleteComment(
                              commentId: c.id,
                              requesterUserId: provider.activeUserId ?? -1,
                            );
                          } on DomainValidationException catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                            }
                          }
                        },
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('История изменений', style: TextStyle(fontWeight: FontWeight.w600)),
          StreamBuilder<List<TaskHistoryRecord>>(
            stream: provider.repository.watchTaskHistory(task.id),
            builder: (context, snapshot) {
              final history = snapshot.data ?? [];
              return Column(
                children: history
                    .map((h) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.history, size: 18),
                          title: Text(h.note.isEmpty ? '${h.previousStatus ?? '—'} → ${h.newStatus}' : h.note),
                          subtitle: Text(h.changedAt.toLocal().toString()),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
