import 'group_member.dart';

class Group {
  final int id;
  final int teacherId;
  final String name;
  final String inviteCode;
  final List<GroupMember> students;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.teacherId,
    required this.name,
    required this.inviteCode,
    this.students = const [],
    required this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      teacherId: json['teacher_id'],
      name: json['name'],
      inviteCode: json['invite_code'] ?? '',
      students:
          (json['students'] as List<dynamic>?)
              ?.map((s) => GroupMember.fromJson(s))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
