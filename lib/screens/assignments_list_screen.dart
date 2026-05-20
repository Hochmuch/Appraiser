import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../repositories/assignment_repository.dart';
import '../cubits/assignments_cubit.dart';
import '../cubits/assignments_state.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/auth_state.dart';

class AssignmentsListScreen extends StatelessWidget {
  const AssignmentsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AssignmentsCubit(context.read<AssignmentRepository>())
            ..loadAssignments(),
      child: const _AssignmentsListView(),
    );
  }
}

class _AssignmentsListView extends StatelessWidget {
  const _AssignmentsListView({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isTeacher = user?.isTeacher ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Домашние задания'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'groups') {
                context.go('/groups');
              }
              if (value == 'logout') {
                context.read<AuthCubit>().logout();
              }
            },
            itemBuilder: (context) => [
              if (user != null)
                PopupMenuItem<String>(
                  enabled: false,
                  value: 'user',
                  child: Row(
                    children: [
                      Icon(
                        user.isTeacher ? Icons.school : Icons.person,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(user.name, overflow: TextOverflow.ellipsis),
                      ),
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
      body: BlocBuilder<AssignmentsCubit, AssignmentsState>(
        builder: (context, state) {
          if (state is AssignmentsInitial || state is AssignmentsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AssignmentsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Ошибка: ${state.message}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        context.read<AssignmentsCubit>().loadAssignments(),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          if (state is AssignmentsLoaded) {
            final assignments = state.assignments;

            if (assignments.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Пока нет домашних заданий'),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.read<AssignmentsCubit>().loadAssignments(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Обновить'),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () =>
                  context.read<AssignmentsCubit>().loadAssignments(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: assignments.length,
                itemBuilder: (context, i) {
                  final a = assignments[i];
                  final groupsText = a.groupNames.isNotEmpty
                      ? 'Группы: ${a.groupNames.join(", ")}'
                      : 'Группы не указаны';
                  return Card(
                    child: ListTile(
                      title: Text(
                        a.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '$groupsText • ${a.createdAt.toLocal().toString().split(".")[0]}\n${a.description}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/assignments/${a.id}'),
                    ),
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/assignments/create'),
              icon: const Icon(Icons.add),
              label: const Text('Создать ДЗ'),
            )
          : null,
    );
  }
}
