import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../repositories/taskflow_repository.dart';
import '../state/taskflow_provider.dart';

class UsersTab extends StatelessWidget {
  const UsersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskFlowProvider>();

    return Scaffold(
      body: StreamBuilder<List<UserRecord>>(
        stream: provider.repository.watchUsers(),
        builder: (context, snapshot) {
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('Пользователей нет. Добавьте первого участника.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFF8BBD0),
                    child: Text(user.name.characters.first.toUpperCase()),
                  ),
                  title: Text(user.name),
                  subtitle: Text(user.email),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      try {
                        await provider.repository.deleteUser(user.id);
                      } on DomainValidationException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddUserDialog(context),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Future<void> _showAddUserDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final provider = context.read<TaskFlowProvider>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый пользователь'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Имя')),
            const SizedBox(height: 10),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              try {
                final id = await provider.repository.createUser(
                  name: nameCtrl.text,
                  email: emailCtrl.text,
                );
                provider.setActiveUser(id);
                if (ctx.mounted) Navigator.pop(ctx);
              } on DomainValidationException catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
