import 'criteria.dart';
import 'submission.dart';

class Assignment {
  final int id;
  final int teacherId;
  final String teacherName;
  final String title;
  final String description;
  final List<int> groupIds;
  final List<String> groupNames;
  final List<Criteria> criteria;
  final List<Submission>? submissions;
  final DateTime createdAt;

  Assignment({
    required this.id,
    required this.teacherId,
    this.teacherName = '',
    required this.title,
    required this.description,
    this.groupIds = const [],
    this.groupNames = const [],
    this.criteria = const [],
    this.submissions,
    required this.createdAt,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'],
      teacherId: json['teacher_id'],
      teacherName: json['teacher_name'] ?? '',
      title: json['title'],
      description: json['description'],
      groupIds:
          (json['group_ids'] as List<dynamic>?)
              ?.map((g) => g as int)
              .toList() ??
          [],
      groupNames:
          (json['group_names'] as List<dynamic>?)
              ?.map((g) => g.toString())
              .toList() ??
          [],
      criteria:
          (json['criteria'] as List<dynamic>?)
              ?.map((c) => Criteria.fromJson(c))
              .toList() ??
          [],
      submissions: (json['submissions'] as List<dynamic>?)
          ?.map((s) => Submission.fromJson(s))
          .toList(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
