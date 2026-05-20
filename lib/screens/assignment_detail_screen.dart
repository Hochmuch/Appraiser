import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/models.dart';
import '../repositories/assignment_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/submission_repository.dart';
import '../cubits/assignment_detail_cubit.dart';

class AssignmentDetailScreen extends StatelessWidget {
  final int assignmentId;
  final void Function(int submissionId) onViewResults;
  final void Function(int submissionId) onViewFiles;
  final void Function(Assignment assignment)? onEdit;
  final VoidCallback onBack;

  const AssignmentDetailScreen({
    super.key,
    required this.assignmentId,
    required this.onViewResults,
    required this.onViewFiles,
    required this.onBack,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AssignmentDetailCubit(
        assignmentRepository: context.read<AssignmentRepository>(),
        submissionRepository: context.read<SubmissionRepository>(),
        assignmentId: assignmentId,
      ),
      child: _AssignmentDetailView(
        onViewResults: onViewResults,
        onViewFiles: onViewFiles,
        onBack: onBack,
        onEdit: onEdit,
      ),
    );
  }
}

class LLMOption {
  final String label;
  final String provider;
  final String model;
  const LLMOption(this.label, this.provider, this.model);
}

class _AssignmentDetailView extends StatefulWidget {
  final void Function(int submissionId) onViewResults;
  final void Function(int submissionId) onViewFiles;
  final void Function(Assignment assignment)? onEdit;
  final VoidCallback onBack;

  const _AssignmentDetailView({
    required this.onViewResults,
    required this.onViewFiles,
    required this.onBack,
    this.onEdit,
  });

  @override
  State<_AssignmentDetailView> createState() => _AssignmentDetailViewState();
}

class _AssignmentDetailViewState extends State<_AssignmentDetailView> {
  static const List<LLMOption> _llmOptions = [
    LLMOption('Gemini 3.1 Flash Lite', 'gemini', 'gemini-3.1-flash-lite'),
    LLMOption('GigaChat 2', 'gigachat', 'GigaChat-2'),
  ];

  final _repoController = TextEditingController();
  LLMOption _selectedReviewOption = _llmOptions.first;

  @override
  void dispose() {
    _repoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        widget.onBack();
        return false;
      },
      child: BlocConsumer<AssignmentDetailCubit, AssignmentDetailState>(
        listener: (context, state) {
          if (state.submitInfoMsg != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.submitInfoMsg!)));
            _repoController.clear();
          }
          if (state.submitError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.submitError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (state.reviewActionMsg != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.reviewActionMsg!)));
          }
          if (state.reviewError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.reviewError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (state.submitInfoMsg != null ||
              state.submitError != null ||
              state.reviewActionMsg != null ||
              state.reviewError != null) {
            context.read<AssignmentDetailCubit>().clearMessages();
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(state.assignment?.title ?? 'Задание'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              actions: [
                if (context.read<AuthRepository>().isTeacher &&
                    state.assignment != null &&
                    widget.onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Редактировать',
                    onPressed: () => widget.onEdit!(state.assignment!),
                  ),
              ],
            ),
            body: _buildBody(context, state),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, AssignmentDetailState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(child: Text('Ошибка: ${state.error}'));
    }
    if (state.assignment == null) {
      return const Center(child: Text('Задание не найдено'));
    }

    final a = state.assignment!;
    final isTeacher = context.read<AuthRepository>().isTeacher;

    return RefreshIndicator(
      onRefresh: () => context.read<AssignmentDetailCubit>().loadAssignment(
        showLoading: false,
      ),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Преподаватель: ${a.teacherName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (a.groupNames.isNotEmpty) ...[
                Text(
                  'Назначено группам:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: a.groupNames
                      .map((name) => Chip(label: Text(name)))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (a.description.isNotEmpty) ...[
                Text(a.description),
                const SizedBox(height: 20),
              ],

              Text(
                'Критерии оценки',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...a.criteria.asMap().entries.map(
                (e) => _buildAssignmentCriteriaCard(e.key + 1, e.value),
              ),

              if (!isTeacher) ...[
                const SizedBox(height: 24),
                const Divider(),
                Text(
                  'Отправить работу',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 520;
                    final repoField = TextField(
                      controller: _repoController,
                      decoration: const InputDecoration(
                        labelText: 'Ссылка на ваш GitHub репозиторий',
                        hintText: 'https://github.com/ваше-имя/repo',
                        border: OutlineInputBorder(),
                      ),
                    );

                    final submitButton = FilledButton(
                      onPressed: state.isSubmitting
                          ? null
                          : () {
                              context
                                  .read<AssignmentDetailCubit>()
                                  .submitRepository(
                                    _repoController.text.trim(),
                                  );
                            },
                      child: state.isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Отправить'),
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          repoField,
                          const SizedBox(height: 12),
                          submitButton,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Column(children: [repoField])),
                        const SizedBox(width: 12),
                        submitButton,
                      ],
                    );
                  },
                ),
              ],

              if (isTeacher && a.submissions != null) ...[
                const SizedBox(height: 24),
                const Divider(),
                Text(
                  'Работы студентов (${a.submissions!.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: DropdownButtonFormField<LLMOption>(
                    initialValue: _selectedReviewOption,
                    decoration: const InputDecoration(
                      labelText: 'Версия модели LLM: ',
                      border: OutlineInputBorder(),
                    ),
                    items: _llmOptions
                        .map(
                          (option) => DropdownMenuItem<LLMOption>(
                            value: option,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedReviewOption = value);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (a.submissions!.isEmpty)
                  const Text('Пока никто не отправил работу'),
                ...a.submissions!.map(
                  (s) =>
                      _buildSubmissionCard(context, s, state.isStartingReview),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentCriteriaCard(int index, Criteria c) {
    final lines = c.description.trim().split('\n');
    final title = lines.first.trim();
    final details = lines.length > 1 ? lines.skip(1).join('\n').trim() : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(63, 81, 181, 0.12),
              border: const Border(
                left: BorderSide(color: Colors.indigo, width: 4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 1, right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color.fromRGBO(63, 81, 181, 0.22),
                    border: Border.all(
                      color: const Color.fromRGBO(63, 81, 181, 0.7),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigoAccent,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Критерий',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color.fromRGBO(255, 255, 255, 0.55),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title.isNotEmpty ? title : 'Критерий $index',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Макс: ${c.maxScore}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (details.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Требования',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color.fromRGBO(63, 81, 181, 0.8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    details,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmissionCard(
    BuildContext context,
    Submission sub,
    bool isStartingReview,
  ) {
    final statusMap = {
      'pending': {'label': 'Не проверено', 'color': Colors.orange},
      'reviewing': {'label': 'Проверяется...', 'color': Colors.blue},
      'completed': {'label': 'Проверено', 'color': Colors.green},
      'failed': {'label': 'Ошибка проверки', 'color': Colors.red},
    };

    final st =
        statusMap[sub.status] ?? {'label': sub.status, 'color': Colors.grey};
    final label = st['label'] as String;
    final color = st['color'] as Color;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sub.studentName.isNotEmpty
                        ? sub.studentName
                        : 'Студент #${sub.studentId}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(
                      (color.r * 255).round(),
                      (color.g * 255).round(),
                      (color.b * 255).round(),
                      0.2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sub.status == 'reviewing') ...[
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              sub.githubRepo,
              style: const TextStyle(fontSize: 13, color: Colors.blue),
            ),
            if (sub.llmProvider.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Проверено с помощью: ${sub.llmProvider}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (sub.status != 'reviewing')
                  FilledButton.icon(
                    onPressed: isStartingReview
                        ? null
                        : () =>
                              context.read<AssignmentDetailCubit>().startReview(
                                sub.id,
                                _selectedReviewOption.provider,
                                _selectedReviewOption.model,
                              ),
                    icon: const Icon(Icons.psychology, size: 18),
                    label: Text(
                      sub.status == 'completed'
                          ? 'Перепроверить (LLM)'
                          : 'Автопроверка (LLM)',
                    ),
                  ),
                if (sub.status == 'completed')
                  OutlinedButton.icon(
                    onPressed: () => widget.onViewResults(sub.id),
                    icon: const Icon(Icons.assessment, size: 18),
                    label: const Text('Результаты'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => widget.onViewFiles(sub.id),
                  icon: const Icon(Icons.code, size: 18),
                  label: const Text('Код'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
