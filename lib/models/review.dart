class Review {
  final int id;
  final int submissionId;
  final int criteriaId;
  final String criteriaDesc;
  final int score;
  final int maxScore;
  final String comment;

  Review({
    required this.id,
    required this.submissionId,
    required this.criteriaId,
    this.criteriaDesc = '',
    required this.score,
    this.maxScore = 0,
    required this.comment,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      submissionId: json['submission_id'],
      criteriaId: json['criteria_id'],
      criteriaDesc: json['criteria_desc'] ?? '',
      score: json['score'],
      maxScore: json['max_score'] ?? 0,
      comment: json['comment'],
    );
  }
}
