import 'review.dart';
import 'review_finding.dart';

class Submission {
  final int id;
  final int assignmentId;
  final int studentId;
  final String studentName;
  final String githubRepo;
  final String llmProvider;
  final String status;
  final List<Review> reviews;
  final List<ReviewFinding> findings;
  final DateTime createdAt;

  Submission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    this.studentName = '',
    required this.githubRepo,
    this.llmProvider = '',
    required this.status,
    this.reviews = const [],
    this.findings = const [],
    required this.createdAt,
  });

  factory Submission.fromJson(Map<String, dynamic> json) {
    return Submission(
      id: json['id'],
      assignmentId: json['assignment_id'],
      studentId: json['student_id'],
      studentName: json['student_name'] ?? '',
      githubRepo: json['github_repo'],
      llmProvider: json['llm_provider'] ?? '',
      status: json['status'],
      reviews:
          (json['reviews'] as List<dynamic>?)
              ?.map((r) => Review.fromJson(r))
              .toList() ??
          [],
      findings:
          (json['findings'] as List<dynamic>?)
              ?.map((f) => ReviewFinding.fromJson(f))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
