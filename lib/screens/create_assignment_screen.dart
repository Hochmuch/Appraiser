import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';

class CreateAssignmentScreen extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback onCreated;
  final VoidCallback onBack;
  final Assignment? editAssignment;

  const CreateAssignmentScreen({
    super.key,
    required this.apiClient,
    required this.onCreated,
    required this.onBack,
    this.editAssignment,
  });

  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CriteriaField {
  final descController = TextEditingController();
  final maxScoreController = TextEditingController(text: '10');
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final List<_CriteriaField> _criteria = [_CriteriaField()];
  List<Group> _groups = [];
  final Set<int> _selectedGroupIds = {};
  bool _groupsLoading = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGroups();
    final edit = widget.editAssignment;
    if (edit != null) {
      _titleController.text = edit.title;
      _descController.text = edit.description;
      _criteria.clear();
      for (final c in edit.criteria) {
        final f = _CriteriaField();
        f.descController.text = c.description;
        f.maxScoreController.text = c.maxScore.toString();
        _criteria.add(f);
      }
      if (_criteria.isEmpty) _criteria.add(_CriteriaField());
      _selectedGroupIds.addAll(edit.groupIds.map((id) => id));
    }
  }

  bool get _isEditing => widget.editAssignment != null;

  Future<void> _loadGroups() async {
    setState(() => _groupsLoading = true);
    try {
      final groups = await widget.apiClient.getMyGroups();
      setState(() => _groups = groups);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Ошибка загрузки групп: $e');
    } finally {
      setState(() => _groupsLoading = false);
    }
  }

  void _addCriteria() {
    setState(() => _criteria.add(_CriteriaField()));
  }

  void _removeCriteria(int index) {
    if (_criteria.length > 1) {
      setState(() => _criteria.removeAt(index));
    }
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Введите название');
      return;
    }

    final criteriaList = _criteria
        .where((c) => c.descController.text.trim().isNotEmpty)
        .map(
          (c) => {
            'description': c.descController.text.trim(),
            'max_score': int.tryParse(c.maxScoreController.text) ?? 10,
          },
        )
        .toList();

    if (criteriaList.isEmpty) {
      setState(() => _error = 'Добавьте хотя бы один критерий');
      return;
    }

    if (_selectedGroupIds.isEmpty) {
      setState(() => _error = 'Выберите хотя бы одну группу');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await widget.apiClient.updateAssignment(
          widget.editAssignment!.id,
          _titleController.text.trim(),
          _descController.text.trim(),
          criteriaList,
          _selectedGroupIds.toList(),
        );
      } else {
        await widget.apiClient.createAssignment(
          _titleController.text.trim(),
          _descController.text.trim(),
          criteriaList,
          _selectedGroupIds.toList(),
        );
      }
      widget.onCreated();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        widget.onBack();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Редактировать задание' : 'Новое задание'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBack,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Название задания',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Описание задания',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Группы, которым назначается задание',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_groupsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                else if (_groups.isEmpty)
                  const Text(
                    'Нет групп. Сначала создайте группу на экране "Группы".',
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _groups.map((g) {
                      final selected = _selectedGroupIds.contains(g.id);
                      return FilterChip(
                        selected: selected,
                        label: Text(g.name),
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _selectedGroupIds.add(g.id);
                            } else {
                              _selectedGroupIds.remove(g.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'Критерии оценки',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: _addCriteria,
                      tooltip: 'Добавить критерий',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(_criteria.length, (i) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 520;

                          final criteriaField = TextField(
                            controller: _criteria[i].descController,
                            maxLines: null,
                            minLines: 2,
                            keyboardType: TextInputType.multiline,
                            decoration: InputDecoration(
                              labelText: 'Критерий ${i + 1}',
                              border: const OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                          );

                          final maxScoreField = SizedBox(
                            width: isNarrow ? double.infinity : 80,
                            child: TextField(
                              controller: _criteria[i].maxScoreController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Макс.',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          );

                          final removeButton = IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => _removeCriteria(i),
                            color: Colors.red,
                          );

                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                criteriaField,
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: maxScoreField),
                                    removeButton,
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(flex: 3, child: criteriaField),
                              const SizedBox(width: 12),
                              maxScoreField,
                              removeButton,
                            ],
                          );
                        },
                      ),
                    ),
                  );
                }),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isEditing ? 'Сохранить' : 'Создать задание'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _loading ? null : widget.onBack,
                  child: const Text('Отмена'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
