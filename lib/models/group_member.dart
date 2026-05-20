class GroupMember {
  final int userId;
  final String email;
  final String name;

  GroupMember({required this.userId, required this.email, required this.name});

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['user_id'],
      email: json['email'] ?? '',
      name: json['name'] ?? '',
    );
  }
}
