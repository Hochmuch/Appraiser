class Criteria {
  final int id;
  final int assignmentId;
  final String description;
  final int maxScore;

  Criteria({
    required this.id,
    required this.assignmentId,
    required this.description,
    required this.maxScore,
  });

  factory Criteria.fromJson(Map<String, dynamic> json) {
    return Criteria(
      id: json['id'],
      assignmentId: json['assignment_id'],
      description: json['description'],
      maxScore: json['max_score'],
    );
  }
}
