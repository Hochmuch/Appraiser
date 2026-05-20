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
