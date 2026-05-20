import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/models.dart';
import '../repositories/group_repository.dart';
import '../services/api_client.dart';
import '../cubits/groups_cubit.dart';
import '../cubits/groups_state.dart';

class GroupsScreen extends StatelessWidget {
  final VoidCallback onBack;

  const GroupsScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          GroupsCubit(context.read<GroupRepository>())..loadGroups(),
      child: _GroupsScreenView(onBack: onBack),
    );
  }
}

class _GroupsScreenView extends StatefulWidget {
  final VoidCallback onBack;

  const _GroupsScreenView({required this.onBack});

  @override
  State<_GroupsScreenView> createState() => _GroupsScreenViewState();
}

class _GroupsScreenViewState extends State<_GroupsScreenView> {
  final _nameController = TextEditingController();
  final _emailsController = TextEditingController();

  Future<void> _showAddStudentsDialog(BuildContext context, Group group) async {
    final emailsController = TextEditingController();
    final cubit = context.read<GroupsCubit>();

    await showDialog(
      context: context,
      builder: (dialogCtx) => BlocProvider.value(
        value: cubit,
        child: BlocConsumer<GroupsCubit, GroupsState>(
          listener: (context, state) {
            if (state is GroupsLoaded) {
              if (state.actionMessage == 'Студенты успешно добавлены') {
                if (Navigator.of(dialogCtx).canPop()) {
                  Navigator.of(dialogCtx).pop();
                }
              }
            }
          },
          builder: (context, state) {
            bool isCreating = false;
            String? actionError;
            if (state is GroupsLoaded) {
              isCreating = state.isCreating;
              actionError = state.actionError;
            }

            return AlertDialog(
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
                  if (actionError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      actionError,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isCreating
                      ? null
                      : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: isCreating
                      ? null
                      : () => cubit.addStudentsToGroup(
                          group.id,
                          emailsController.text,
                        ),
                  child: isCreating
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Добавить'),
                ),
              ],
            );
          },
        ),
      ),
    );
    cubit.clearMessages();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupsCubit, GroupsState>(
      listener: (context, state) {
        if (state is GroupsLoaded) {
          if (state.actionMessage != null &&
              state.actionMessage != 'Студенты успешно добавлены') {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.actionMessage!)));
            if (state.actionMessage == 'Группа успешно создана') {
              _nameController.clear();
              _emailsController.clear();
            }
          }
          if (state.actionError != null &&
              state.actionMessage != 'Студенты успешно добавлены') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionError!),
                backgroundColor: Colors.red,
              ),
            );
          }
          if (state.actionMessage != null || state.actionError != null) {
            if (state.actionMessage != 'Студенты успешно добавлены') {
              context.read<GroupsCubit>().clearMessages();
            }
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Группы'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onBack,
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () => context.read<GroupsCubit>().loadGroups(),
            child: _buildBody(context, state),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, GroupsState state) {
    if (state is GroupsInitial || state is GroupsLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (state is GroupsError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Ошибка: ${state.message}',
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.read<GroupsCubit>().loadGroups(),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is GroupsLoaded) {
      return ListView(
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
                  const Text(
                    'Группа будет создана без студентов. Ссылка для входа в группу появится после создания.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: state.isCreating
                        ? null
                        : () => context.read<GroupsCubit>().createGroup(
                            _nameController.text,
                            '',
                          ),
                    child: state.isCreating
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
          if (state.groups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Группы пока не созданы',
                textAlign: TextAlign.center,
              ),
            )
          else
            ...state.groups.map(
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
                    if (g.inviteCode.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Ссылка: ${ApiClient.baseUrl.replaceAll('/api', '')}/groups/join/${g.inviteCode}',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () async {
                                final inviteLink =
                                    '${ApiClient.baseUrl.replaceAll('/api', '')}/groups/join/${g.inviteCode}';
                                await Clipboard.setData(
                                  ClipboardData(text: inviteLink),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ссылка скопирована'),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddStudentsDialog(context, g),
                        icon: const Icon(Icons.person_add_outlined, size: 18),
                        label: const Text('Добавить студентов'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
