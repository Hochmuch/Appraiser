import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';

class ReviewResultsScreen extends StatefulWidget {
  final ApiClient apiClient;
  final int submissionId;
  final VoidCallback onBack;

  const ReviewResultsScreen({
    super.key,
    required this.apiClient,
    required this.submissionId,
    required this.onBack,
  });

  @override
  State<ReviewResultsScreen> createState() => _ReviewResultsScreenState();
}

class _ReviewResultsScreenState extends State<ReviewResultsScreen> {
  Submission? _submission;
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
      final s = await widget.apiClient.getSubmissionResults(
        widget.submissionId,
      );
      setState(() => _submission = s);
    } catch (e) {
      setState(() => _error = e.toString());
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
          title: const Text('Результаты проверки'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBack,
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Ошибка: $_error'));

    final s = _submission!;
    final totalScore = s.reviews.fold<int>(0, (sum, r) => sum + r.score);
    final totalMax = s.reviews.fold<int>(0, (sum, r) => sum + r.maxScore);

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
              
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.studentName.isNotEmpty
                                  ? s.studentName
                                  : 'Студент #${s.studentId}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.githubRepo,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Статус: ${_statusText(s.status)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (s.reviews.isNotEmpty)
                        Column(
                          children: [
                            Text(
                              '$totalScore/$totalMax',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Text('Итого'),
                          ],
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
                  (f) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                          const SizedBox(height: 6),
                          Text('${f.filePath}:${f.startLine}-${f.endLine}'),
                          const SizedBox(height: 8),
                          Text(f.comment),
                          if (f.suggestion.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Рекомендация: ${f.suggestion}'),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              
              ...s.reviews.asMap().entries.map(
                (e) => _buildCriteriaCard(e.key + 1, e.value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCriteriaCard(int index, Review r) {
    final color = _scoreColor(r.score, r.maxScore);
    final ratio = r.maxScore > 0 ? r.score / r.maxScore : 0.0;
    final percent = (ratio * 100).round();

    
    final descLines = r.criteriaDesc.trim().split('\n');
    final title = descLines.first.trim();
    final details = descLines.length > 1
        ? descLines.skip(1).join('\n').trim()
        : '';

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
              color: color.withOpacity(0.12),
              border: Border(
                left: BorderSide(color: color, width: 4),
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
                    color: color.withOpacity(0.25),
                    border: Border.all(color: color.withOpacity(0.6)),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isNotEmpty ? title : 'Критерий $index',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (details.isNotEmpty) ...
                        [
                          const SizedBox(height: 4),
                          Text(
                            details,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.55),
                              height: 1.4,
                            ),
                          ),
                        ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${r.score} / ${r.maxScore}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          LinearProgressIndicator(
            value: ratio.toDouble(),
            minHeight: 3,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
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
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  Color _scoreColor(int score, int maxScore) {
    if (maxScore == 0) return Colors.grey;
    final ratio = score / maxScore;
    if (ratio >= 0.8) return Colors.green;
    if (ratio >= 0.5) return Colors.orange;
    return Colors.red;
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
