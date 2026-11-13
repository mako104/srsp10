import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../state/taskflow_provider.dart';
import 'dashboard_tab.dart';
import 'projects_tab.dart';
import 'tasks_tab.dart';
import 'trash_screen.dart';
import 'users_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskFlowProvider>();

    final screens = const [
      ProjectsTab(),
      TasksTab(),
      UsersTab(),
      DashboardTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskFlow', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          StreamBuilder<List<UserRecord>>(
            stream: provider.repository.watchUsers(),
            builder: (context, snapshot) {
              final users = snapshot.data ?? [];
              if (users.isEmpty) return const SizedBox.shrink();
              final currentId = provider.activeUserId ?? users.first.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: users.any((u) => u.id == currentId) ? currentId : users.first.id,
                    icon: const Icon(Icons.person_outline, color: Color(0xFF880E4F)),
                    items: users
                        .map((u) => DropdownMenuItem(
                              value: u.id,
                              child: Text(u.name, style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (val) => provider.setActiveUser(val),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Корзина задач',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TrashScreen()),
              );
            },
          ),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: const Color(0xFFFCE4EC),
        indicatorColor: const Color(0xFFF8BBD0),
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Проекты'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), label: 'Задачи'),
          NavigationDestination(icon: Icon(Icons.group_outlined), label: 'Участники'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Статистика'),
        ],
      ),
    );
  }
}
