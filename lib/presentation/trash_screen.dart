import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../state/taskflow_provider.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskFlowProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Корзина задач')),
      body: StreamBuilder<List<TaskRecord>>(
        stream: provider.repository.watchDeletedTasks(),
        builder: (context, snapshot) {
          final deleted = snapshot.data ?? [];
          if (deleted.isEmpty) {
            return const Center(child: Text('Корзина пуста'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: deleted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final task = deleted[index];
              return Card(
                child: ListTile(
                  title: Text(task.title),
                  subtitle: Text('Удалена: ${task.deletedAt?.toLocal()}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Восстановить',
                        icon: const Icon(Icons.restore),
                        onPressed: () => provider.repository.restoreTask(task.id),
                      ),
                      IconButton(
                        tooltip: 'Удалить навсегда',
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        onPressed: () => provider.repository.permanentlyDeleteTask(task.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
