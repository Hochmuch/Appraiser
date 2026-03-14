import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_client.dart';

class GroupsScreen extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback onBack;

  const GroupsScreen({
    super.key,
    required this.apiClient,
    required this.onBack,
  });

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<Group>? _groups;
  bool _loading = true;
  String? _error;

  final _nameController = TextEditingController();
  final _emailsController = TextEditingController();
  bool _creating = false;

  Future<void> _showAddStudentsDialog(Group group) async {
    final emailsController = TextEditingController();
    String? dialogError;
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Добавить студентов в «${group.name}»'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: emailsController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText:
                      'Email студентов (через запятую или с новой строки)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 8),
                Text(
                  dialogError!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final emails = emailsController.text
                          .split(RegExp(r'[\n,;]'))
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();
                      if (emails.isEmpty) {
                        setDialogState(
                          () => dialogError = 'Введите хотя бы один email',
                        );
                        return;
                      }
                      setDialogState(() {
                        submitting = true;
                        dialogError = null;
                      });
                      try {
                        await widget.apiClient.addStudentsToGroup(
                          group.id,
                          emails,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        await _load();
                      } on ApiException catch (e) {
                        setDialogState(() {
                          submitting = false;
                          dialogError = e.message;
                        });
                      } catch (e) {
                        setDialogState(() {
                          submitting = false;
                          dialogError = 'Ошибка: $e';
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

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
      final groups = await widget.apiClient.getMyGroups();
      setState(() => _groups = groups);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введите название группы');
      return;
    }

    final emails = _emailsController.text
        .split(RegExp(r'[\n,;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      await widget.apiClient.createGroup(name, emails);
      _nameController.clear();
      _emailsController.clear();
      await _load();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
    } finally {
      setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Группы'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Создать группу',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Название группы',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailsController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText:
                            'Email студентов (через запятую или с новой строки)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _creating ? null : _createGroup,
                      child: _creating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Создать группу'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_groups == null || _groups!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Группы пока не созданы'),
              )
            else
              ..._groups!.map(
                (g) => Card(
                  child: ExpansionTile(
                    title: Text(g.name),
                    subtitle: Text('Студентов: ${g.students.length}'),
                    children: [
                      if (g.students.isEmpty)
                        const ListTile(title: Text('Нет студентов в группе')),
                      ...g.students.map(
                        (s) => ListTile(
                          dense: true,
                          title: Text(
                            s.name.isNotEmpty ? s.name : 'ID ${s.userId}',
                          ),
                          subtitle: Text(s.email),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddStudentsDialog(g),
                          icon: const Icon(Icons.person_add_outlined, size: 18),
                          label: const Text('Добавить студентов'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
