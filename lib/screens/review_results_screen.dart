import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/models.dart';
import '../cubits/review_results_cubit.dart';
import '../cubits/review_results_state.dart';

class ReviewResultsScreen extends StatelessWidget {
  final int submissionId;
  final VoidCallback onBack;

  const ReviewResultsScreen({
    super.key,
    required this.submissionId,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ReviewResultsCubit(context.read())..loadResults(submissionId),
      child: _ReviewResultsView(onBack: onBack),
    );
  }
}

class _ReviewResultsView extends StatelessWidget {
  final VoidCallback onBack;

  const _ReviewResultsView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        onBack();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Результаты проверки'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
          ),
        ),
        body: BlocBuilder<ReviewResultsCubit, ReviewResultsState>(
          builder: (context, state) {
            if (state is ReviewResultsInitial ||
                state is ReviewResultsLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ReviewResultsError) {
              return Center(child: Text('Ошибка: ${state.message}'));
            }

            if (state is ReviewResultsLoaded) {
              return _buildContent(context, state.submission);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Submission s) {
    final scheme = Theme.of(context).colorScheme;
    const summaryFg = Colors.white;
    final totalScore = s.reviews.fold<int>(0, (sum, r) => sum + r.score);
    final totalMax = s.reviews.fold<int>(0, (sum, r) => sum + r.maxScore);

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<ReviewResultsCubit>().loadResults(s.id);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ColoredBox(
                        color: scheme.primary,
                        child: const SizedBox(
                          height: 4,
                          width: double.infinity,
                        ),
                      ),
                      Container(
                        color: const Color(0xFF2A2A2A),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        child: Text(
                          'Информация о проверке',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: summaryFg,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(color: summaryFg),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    s.githubRepo.isNotEmpty
                                        ? s.githubRepo
                                        : 'Репозиторий не указан',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: summaryFg.withOpacity(0.85),
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Статус: ${_statusText(s.status)}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: summaryFg.withOpacity(0.85),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            if (s.reviews.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$totalScore/$totalMax',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: summaryFg,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Итого',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: summaryFg.withOpacity(0.85),
                                        ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (s.reviews.isEmpty && s.status == 'reviewing') ...[
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Проверка выполняется...'),
                    ],
                  ),
                ),
              ],

              if (s.reviews.isEmpty && s.status != 'reviewing')
                const Text('Нет результатов проверки'),

              if (s.findings.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Замечания по коду',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...s.findings.map(
                  (f) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.08),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(
                              _severityColor(f.severity).red,
                              _severityColor(f.severity).green,
                              _severityColor(f.severity).blue,
                              0.2,
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  f.title.isNotEmpty ? f.title : 'Замечание',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _severityColor(f.severity),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  f.severity,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.comment),
                              if (f.suggestion.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Рекомендация: ${f.suggestion}',
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (s.reviews.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Детализация оценок по критериям',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...s.reviews.map(
                  (r) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(
                              _scoreColor(r.score, r.maxScore).red,
                              _scoreColor(r.score, r.maxScore).green,
                              _scoreColor(r.score, r.maxScore).blue,
                              0.18,
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.criteriaDesc,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                '${r.score} / ${r.maxScore}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (r.comment.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 13,
                                      color: Colors.white38,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Комментарий проверки',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white38,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  r.comment,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _statusText(String s) {
    if (s == 'completed') return 'Завершено';
    if (s == 'reviewing') return 'Проверяется';
    if (s == 'failed' || s == 'error') return 'Ошибка проверки';
    return s;
  }

  Color _scoreColor(int score, int maxScore) {
    if (maxScore == 0) return Colors.grey;
    final ratio = score / maxScore;
    if (ratio >= 0.8) return Colors.green;
    if (ratio >= 0.5) return Colors.orange;
    return Colors.red;
  }

  Color _severityColor(String sev) {
    switch (sev.toLowerCase()) {
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
