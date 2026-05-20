class User {
  final int id;
  final String email;
  final String name;
  final String role;
  final bool isTeacher; // старая штука
  final int? githubId;
  final String? githubLogin;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.githubId,
    this.githubLogin,
  }) : isTeacher = role == 'teacher';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      role: json['role'] ?? 'student',
      githubId: json['github_id'] as int?,
      githubLogin: json['github_login'] as String?,
    );
  }
}
