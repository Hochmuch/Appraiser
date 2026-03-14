import 'dart:async';

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';

class AssignmentDetailScreen extends StatefulWidget {
  final ApiClient apiClient;
  final int assignmentId;
  final void Function(int submissionId) onViewResults;
  final void Function(int submissionId) onViewFiles;
  final void Function(Assignment assignment)? onEdit;
  final VoidCallback onBack;

  const AssignmentDetailScreen({
    super.key,
    required this.apiClient,
    required this.assignmentId,
    required this.onViewResults,
    required this.onViewFiles,
    required this.onBack,
    this.onEdit,
  });

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  Assignment? _assignment;
  bool _loading = true;
  String? _error;
  final _repoController = TextEditingController();
  Timer? _reviewPollingTimer;
  bool _pollRequestInFlight = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reviewPollingTimer?.cancel();
    _repoController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final a = await widget.apiClient.getAssignment(widget.assignmentId);
      if (!mounted) return;

      final hadReviewingSubmission =
          _assignment?.submissions?.any((s) => s.status == 'reviewing') ??
          false;
      final hasReviewingSubmission =
          a.submissions?.any((s) => s.status == 'reviewing') ?? false;

      setState(() {
        _assignment = a;
        _error = null;
      });

      _syncReviewPolling(hasReviewingSubmission);

      if (hadReviewingSubmission && !hasReviewingSubmission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Проверка завершена. Результаты обновлены.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      if (showLoading) {
        setState(() => _loading = false);
      }
    }
  }

  void _syncReviewPolling(bool shouldPoll) {
    if (!shouldPoll) {
      _reviewPollingTimer?.cancel();
      _reviewPollingTimer = null;
      return;
    }

    if (_reviewPollingTimer != null) return;

    _reviewPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _pollRequestInFlight) return;
      _pollRequestInFlight = true;
      try {
        await _load(showLoading: false);
      } finally {
        _pollRequestInFlight = false;
      }
    });
  }

  Future<void> _submit() async {
    if (_repoController.text.trim().isEmpty) return;

    setState(() => _submitting = true);
    try {
      await widget.apiClient.submitAssignment(
        widget.assignmentId,
        _repoController.text.trim(),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Работа отправлена!')));
      _repoController.clear();
      _load();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _startReview(int submissionId) async {
    try {
      await widget.apiClient.startReview(submissionId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Проверка запущена!')));
      _syncReviewPolling(true);
      await Future.delayed(const Duration(seconds: 1));
      await _load(showLoading: false);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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
          title: Text(_assignment?.title ?? 'Задание'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBack,
          ),
          actions: [
            if (widget.apiClient.isTeacher &&
                _assignment != null &&
                widget.onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Редактировать',
                onPressed: () => widget.onEdit!(_assignment!),
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('Ошибка: $_error'));
    }

    final a = _assignment!;
    final isTeacher = widget.apiClient.isTeacher;

    return RefreshIndicator(
      onRefresh: _load,
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
                        labelText: 'Ссылка на GitHub репозиторий',
                        hintText: 'https://github.com/user/repo',
                        border: OutlineInputBorder(),
                      ),
                    );

                    final submitButton = FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
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
                      children: [
                        Expanded(child: repoField),
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
                if (a.submissions!.isEmpty)
                  const Text('Пока никто не отправил работу'),
                ...a.submissions!.map((s) => _buildSubmissionCard(s)),
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
              color: Colors.indigo.withOpacity(0.12),
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
                    color: Colors.indigo.withOpacity(0.22),
                    border: Border.all(color: Colors.indigo.withOpacity(0.7)),
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
                          color: Colors.white.withOpacity(0.55),
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
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.4),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Colors.white.withOpacity(0.86),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmissionCard(Submission s) {
    final statusColor = _statusColor(s.status);

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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.14),
              border: Border(left: BorderSide(color: statusColor, width: 4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.studentName.isNotEmpty
                            ? s.studentName
                            : 'Студент #${s.studentId}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        s.githubRepo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.72),
                          height: 1.35,
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
                    color: statusColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusIcon(s.status),
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _statusText(s.status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (s.status == 'pending' ||
                    s.status == 'error' ||
                    s.status == 'completed')
                  FilledButton.icon(
                    onPressed: () => _startReview(s.id),
                    icon: Icon(
                      s.status == 'completed'
                          ? Icons.refresh
                          : Icons.play_arrow,
                      size: 16,
                    ),
                    label: Text(
                      s.status == 'completed'
                          ? 'Проверить заново'
                          : 'Запустить проверку',
                    ),
                  ),
                if (s.status == 'completed')
                  OutlinedButton.icon(
                    onPressed: () => widget.onViewResults(s.id),
                    icon: const Icon(Icons.assessment_outlined, size: 16),
                    label: const Text('Результаты'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => widget.onViewFiles(s.id),
                  icon: const Icon(Icons.code, size: 16),
                  label: const Text('Файлы проекта'),
                ),
                if (s.status == 'reviewing')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 6),
                      Text('Проверка выполняется...'),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'reviewing':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'reviewing':
        return Icons.hourglass_top;
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.schedule;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'pending':
        return 'Ожидает проверки';
      case 'reviewing':
        return 'Проверяется...';
      case 'completed':
        return 'Проверено';
      case 'error':
        return 'Ошибка проверки';
      default:
        return status;
    }
  }
}
