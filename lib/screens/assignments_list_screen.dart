import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';

class AssignmentsListScreen extends StatefulWidget {
  final ApiClient apiClient;
  final void Function(int id) onAssignmentTap;
  final VoidCallback onCreateAssignment;
  final VoidCallback onManageGroups;
  final VoidCallback onLogout;

  const AssignmentsListScreen({
    super.key,
    required this.apiClient,
    required this.onAssignmentTap,
    required this.onCreateAssignment,
    required this.onManageGroups,
    required this.onLogout,
  });

  @override
  State<AssignmentsListScreen> createState() => _AssignmentsListScreenState();
}

class _AssignmentsListScreenState extends State<AssignmentsListScreen> {
  List<Assignment>? _assignments;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final assignments = await widget.apiClient.getAssignments();
      setState(() => _assignments = assignments);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.apiClient.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Домашние задания'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'groups') {
                widget.onManageGroups();
              }
              if (value == 'logout') {
                widget.onLogout();
              }
            },
            itemBuilder: (context) => [
              if (user != null)
                PopupMenuItem<String>(
                  enabled: false,
                  value: 'user',
                  child: Row(
                    children: [
                      Icon(user.isTeacher ? Icons.school : Icons.person, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(user.name, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              if (user?.isTeacher == true)
                const PopupMenuItem<String>(
                  value: 'groups',
                  child: Row(
                    children: [
                      Icon(Icons.groups, size: 18),
                      SizedBox(width: 8),
                      Text('Группы'),
                    ],
                  ),
                ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Выйти'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: widget.apiClient.isTeacher
          ? FloatingActionButton.extended(
              onPressed: widget.onCreateAssignment,
              icon: const Icon(Icons.add),
              label: const Text('Создать ДЗ'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ошибка: $_error'),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }

    if (_assignments == null || _assignments!.isEmpty) {
      return const Center(
        child: Text('Пока нет домашних заданий'),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _assignments!.length,
        itemBuilder: (context, i) {
          final a = _assignments![i];
          final groupsText = a.groupNames.isNotEmpty
              ? 'Группы: ${a.groupNames.join(', ')}'
              : 'Группы не указаны';
          return Card(
            child: ListTile(
              title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${a.teacherName} • ${_formatDate(a.createdAt)}\n$groupsText',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => widget.onAssignmentTap(a.id),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}
