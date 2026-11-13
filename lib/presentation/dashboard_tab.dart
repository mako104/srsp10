import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/benchmark_helper.dart';
import '../models/dashboard_stats.dart';
import '../state/taskflow_provider.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  BenchmarkResult? _benchResult;
  bool _runningBench = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskFlowProvider>();

    return FutureBuilder<DashboardStats>(
      future: provider.loadStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricCard(title: 'Проектов', value: '${stats.totalProjects}'),
                _MetricCard(title: 'Всего задач', value: '${stats.totalTasks}'),
                _MetricCard(title: 'Завершено', value: '${stats.completedTasks}'),
                _MetricCard(title: 'В работе / Ожидает', value: '${stats.incompleteTasks}'),
                _MetricCard(title: 'Просрочено', value: '${stats.overdueTasks}'),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Задачи по приоритетам', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: stats.tasksByPriority.entries
                      .map((e) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [Text(e.key.label), Text('${e.value}')],
                          ))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Прогресс проектов', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ...stats.projectProgress.map((p) => Card(
                  child: ListTile(
                    title: Text(p.projectTitle),
                    subtitle: LinearProgressIndicator(value: p.percentage / 100),
                    trailing: Text('${p.percentage.toStringAsFixed(0)}%'),
                  ),
                )),
            const SizedBox(height: 16),
            const Text('Нагрузка исполнителей', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ...stats.tasksByAssignee.map((a) => ListTile(
                  dense: true,
                  title: Text(a.userName),
                  trailing: Text('${a.taskCount} задач'),
                )),
            const Divider(height: 24),
            ElevatedButton.icon(
              onPressed: _runningBench
                  ? null
                  : () async {
                      setState(() => _runningBench = true);
                      final res = await provider.runBenchmark();
                      setState(() {
                        _benchResult = res;
                        _runningBench = false;
                      });
                    },
              icon: const Icon(Icons.speed),
              label: Text(_runningBench
                  ? 'Генерация 10 000 задач...'
                  : 'Тест производительности (1000 юзеров / 100 проектов / 10 000 задач)'),
            ),
            if (_benchResult != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Вставка данных: ${_benchResult!.insertDuration.inMilliseconds} мс\n'
                    'Поиск С индексами: ${_benchResult!.indexedQueryDuration.inMicroseconds} мкс\n'
                    'Поиск БЕЗ индексов: ${_benchResult!.unindexedQueryDuration.inMicroseconds} мкс\n'
                    'Найдено записей: ${_benchResult!.matchedRows}',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  const _MetricCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 155,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFD81B60))),
            ],
          ),
        ),
      ),
    );
  }
}
