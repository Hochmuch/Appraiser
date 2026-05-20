class ReviewFinding {
  final int id;
  final int submissionId;
  final int? criteriaId;
  final int? sourceFileId;
  final String sourceFilePath;
  final int startLine;
  final int endLine;
  final String severity;
  final String title;
  final String comment;
  final String suggestion;
  final String source;

  ReviewFinding({
    required this.id,
    required this.submissionId,
    this.criteriaId,
    this.sourceFileId,
    this.sourceFilePath = '',
    required this.startLine,
    required this.endLine,
    required this.severity,
    required this.title,
    required this.comment,
    this.suggestion = '',
    this.source = 'llm',
  });

  factory ReviewFinding.fromJson(Map<String, dynamic> json) {
    return ReviewFinding(
      id: json['id'] ?? 0,
      submissionId: json['submission_id'] ?? 0,
      criteriaId: json['criteria_id'],
      sourceFileId: json['source_file_id'],
      sourceFilePath: json['source_file_path'] ?? '',
      startLine: json['start_line'] ?? 1,
      endLine: json['end_line'] ?? 1,
      severity: json['severity'] ?? 'info',
      title: json['title'] ?? '',
      comment: json['comment'] ?? '',
      suggestion: json['suggestion'] ?? '',
      source: json['source'] ?? 'llm',
    );
  }
}
