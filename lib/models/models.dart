class User {
  final int id;
  final String email;
  final String name;
  final bool isTeacher;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.isTeacher,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      isTeacher: json['is_teacher'] ?? false,
    );
  }
}

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

class Group {
  final int id;
  final int teacherId;
  final String name;
  final List<GroupMember> students;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.teacherId,
    required this.name,
    this.students = const [],
    required this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      teacherId: json['teacher_id'],
      name: json['name'],
      students:
          (json['students'] as List<dynamic>?)
              ?.map((s) => GroupMember.fromJson(s))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

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

class Submission {
  final int id;
  final int assignmentId;
  final int studentId;
  final String studentName;
  final String githubRepo;
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

class ReviewFinding {
  final int id;
  final int submissionId;
  final int? criteriaId;
  final String filePath;
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
    required this.filePath,
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
      filePath: json['file_path'] ?? '',
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

class GitHubRepoFile {
  final String path;
  final String content;

  GitHubRepoFile({required this.path, required this.content});

  factory GitHubRepoFile.fromJson(Map<String, dynamic> json) {
    return GitHubRepoFile(
      path: json['path'] ?? '',
      content: json['content'] ?? '',
    );
  }
}

class GitHubDeviceStart {
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int expiresIn;
  final int interval;

  GitHubDeviceStart({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  factory GitHubDeviceStart.fromJson(Map<String, dynamic> json) {
    return GitHubDeviceStart(
      deviceCode: json['device_code'],
      userCode: json['user_code'],
      verificationUri: json['verification_uri'],
      expiresIn: json['expires_in'] ?? 600,
      interval: json['interval'] ?? 5,
    );
  }
}

class GitHubDevicePollResult {
  final bool pending;

  GitHubDevicePollResult({required this.pending});
}
