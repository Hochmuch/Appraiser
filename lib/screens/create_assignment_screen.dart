import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/models.dart';
import '../repositories/assignment_repository.dart';
import '../repositories/group_repository.dart';
import '../cubits/create_assignment_cubit.dart';
import '../cubits/create_assignment_state.dart';

class CreateAssignmentScreen extends StatelessWidget {
  final VoidCallback onCreated;
  final VoidCallback onBack;
  final Assignment? editAssignment;

  const CreateAssignmentScreen({
    super.key,
    required this.onCreated,
    required this.onBack,
    this.editAssignment,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CreateAssignmentCubit(
        context.read<AssignmentRepository>(),
        context.read<GroupRepository>(),
      ),
      child: _CreateAssignmentView(
        onCreated: onCreated,
        onBack: onBack,
        editAssignment: editAssignment,
      ),
    );
  }
}

class _CriteriaField {
  final descController = TextEditingController();
  final maxScoreController = TextEditingController(text: '10');
}

class _CreateAssignmentView extends StatefulWidget {
  final VoidCallback onCreated;
  final VoidCallback onBack;
  final Assignment? editAssignment;

  const _CreateAssignmentView({
    required this.onCreated,
    required this.onBack,
    this.editAssignment,
  });

  @override
  State<_CreateAssignmentView> createState() => _CreateAssignmentViewState();
}

class _CreateAssignmentViewState extends State<_CreateAssignmentView> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final List<_CriteriaField> _criteria = [_CriteriaField()];
  final Set<int> _selectedGroupIds = {};

  @override
  void initState() {
    super.initState();
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

  void _addCriteria() {
    setState(() => _criteria.add(_CriteriaField()));
  }

  void _removeCriteria(int index) {
    if (_criteria.length > 1) {
      setState(() => _criteria.removeAt(index));
    }
  }

  void _submit(BuildContext context) {
    final criteriaList = _criteria
        .where((c) => c.descController.text.trim().isNotEmpty)
        .map(
          (c) => {
            'description': c.descController.text.trim(),
            'max_score': int.tryParse(c.maxScoreController.text) ?? 10,
          },
        )
        .toList();

    context.read<CreateAssignmentCubit>().submit(
      _isEditing,
      widget.editAssignment,
      _titleController.text.trim(),
      _descController.text.trim(),
      criteriaList,
      _selectedGroupIds.toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        widget.onBack();
        return false;
      },
      child: BlocConsumer<CreateAssignmentCubit, CreateAssignmentState>(
        listener: (context, state) {
          if (state is CreateAssignmentSuccess) {
            widget.onCreated();
          } else if (state is CreateAssignmentGroupsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          final isSubmitting = state is CreateAssignmentSubmitting;
          final errorMessage = state is CreateAssignmentError
              ? state.message
              : null;

          List<Group> groups = [];
          if (state is CreateAssignmentGroupsLoaded) groups = state.groups;
          if (state is CreateAssignmentSubmitting) groups = state.groups;
          if (state is CreateAssignmentError) groups = state.groups;

          final isGroupsLoading =
              state is CreateAssignmentInitial ||
              state is CreateAssignmentLoadingGroups;

          return Scaffold(
            appBar: AppBar(
              title: Text(
                _isEditing ? 'Редактировать задание' : 'Новое задание',
              ),
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
                    if (isGroupsLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      )
                    else if (groups.isEmpty)
                      const Text(
                        'Нет групп. Сначала создайте группу на экране "Группы".',
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: groups.map((g) {
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: isSubmitting ? null : () => _submit(context),
                      icon: isSubmitting
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
                      onPressed: isSubmitting ? null : widget.onBack,
                      child: const Text('Отмена'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
