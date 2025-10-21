// main.dart
// Flutter single-file Task Manager app using StatefulWidget + setState
// Features: add/read/update/delete tasks, priorities (Low/Medium/High),
// sort by priority (High first), change priority after creation,
// persistence with shared_preferences, light/dark theme toggle.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TaskApp());
}

class TaskApp extends StatefulWidget {
  const TaskApp({super.key});

  @override
  State<TaskApp> createState() => _TaskAppState();
}

class _TaskAppState extends State<TaskApp> {
  bool _isDark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: TaskListScreen(
        onToggleTheme: () => setState(() => _isDark = !_isDark),
        isDark: _isDark,
      ),
    );
  }
}

enum PriorityLevel { low, medium, high }

extension PriorityExtension on PriorityLevel {
  String get label {
    switch (this) {
      case PriorityLevel.low:
        return 'Low';
      case PriorityLevel.medium:
        return 'Medium';
      case PriorityLevel.high:
        return 'High';
    }
  }

  int get weight {
    switch (this) {
      case PriorityLevel.high:
        return 3;
      case PriorityLevel.medium:
        return 2;
      case PriorityLevel.low:
        return 1;
    }
  }

  static PriorityLevel fromString(String s) {
    return PriorityLevel.values.firstWhere(
        (e) => e.toString().split('.').last == s,
        orElse: () => PriorityLevel.low);
  }
}

class Task {
  String name;
  bool completed;
  PriorityLevel priority;

  Task({required this.name, this.completed = false, this.priority = PriorityLevel.low});

  Map<String, dynamic> toJson() => {
        'name': name,
        'completed': completed,
        'priority': priority.toString().split('.').last,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        name: json['name'] ?? '',
        completed: json['completed'] ?? false,
        priority: PriorityExtension.fromString(json['priority'] ?? 'low'),
      );
}

class TaskListScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;
  const TaskListScreen({super.key, required this.onToggleTheme, required this.isDark});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _controller = TextEditingController();
  PriorityLevel _selectedPriority = PriorityLevel.medium;
  List<Task> _tasks = [];
  late SharedPreferences _prefs;

  static const String _kTasksKey = 'tasks_v1';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    _prefs = await SharedPreferences.getInstance();
    final String? raw = _prefs.getString(_kTasksKey);
    if (raw != null) {
      try {
        final List<dynamic> decoded = json.decode(raw);
        _tasks = decoded.map((e) => Task.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (_) {
        _tasks = [];
      }
      _sortTasks();
      setState(() {});
    }
  }

  Future<void> _saveTasks() async {
    final String raw = json.encode(_tasks.map((t) => t.toJson()).toList());
    await _prefs.setString(_kTasksKey, raw);
  }

  void _addTask() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _tasks.add(Task(name: name, priority: _selectedPriority));
      _controller.clear();
      _selectedPriority = PriorityLevel.medium;
      _sortTasks();
    });
    _saveTasks();
  }

  void _toggleCompleted(int index, bool? value) {
    setState(() {
      _tasks[index].completed = value ?? false;
    });
    _saveTasks();
  }

  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
    _saveTasks();
  }

  void _changePriority(int index, PriorityLevel newPriority) {
    setState(() {
      _tasks[index].priority = newPriority;
      _sortTasks();
    });
    _saveTasks();
  }

  void _sortTasks() {
    _tasks.sort((a, b) {
      // Higher priority first; keep completed tasks lower than incompleted at same priority
      final p = b.priority.weight.compareTo(a.priority.weight);
      if (p != 0) return p;
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  Future<void> _clearCompleted() async {
    setState(() {
      _tasks.removeWhere((t) => t.completed);
    });
    _saveTasks();
  }

  Widget _priorityChip(PriorityLevel p) {
    return Chip(label: Text(p.label));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(widget.isDark ? Icons.wb_sunny : Icons.nights_stay),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            tooltip: 'Clear completed',
            icon: const Icon(Icons.cleaning_services),
            onPressed: _tasks.any((t) => t.completed) ? _clearCompleted : null,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Task name',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<PriorityLevel>(
                  value: _selectedPriority,
                  onChanged: (v) => setState(() => _selectedPriority = v ?? PriorityLevel.medium),
                  items: PriorityLevel.values
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                      .toList(),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTask,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _tasks.isEmpty
                  ? const Center(child: Text('No tasks yet — add one!'))
                  : ListView.builder(
                      itemCount: _tasks.length,
                      itemBuilder: (context, idx) {
                        final task = _tasks[idx];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: Checkbox(
                              value: task.completed,
                              onChanged: (v) => _toggleCompleted(idx, v),
                            ),
                            title: Text(
                              task.name,
                              style: task.completed
                                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                                  : null,
                            ),
                            subtitle: Row(
                              children: [
                                Text('Priority: ${task.priority.label}'),
                                const SizedBox(width: 8),
                                _priorityChip(task.priority),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PopupMenuButton<PriorityLevel>(
                                  onSelected: (p) => _changePriority(idx, p),
                                  itemBuilder: (c) => PriorityLevel.values
                                      .map((p) => PopupMenuItem(value: p, child: Text('Set ${p.label}')))
                                      .toList(),
                                  icon: const Icon(Icons.flag),
                                  tooltip: 'Change priority',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteTask(idx),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
