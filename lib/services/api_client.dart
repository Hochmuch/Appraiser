import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiClient {
  
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  
  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8080/api';
    }
    return 'http://10.0.2.2:8080/api';
  }

  String? _token;
  User? _currentUser;
  final Duration _requestTimeout = const Duration(seconds: 12);
  final Duration _filesRequestTimeout = const Duration(seconds: 90);
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  String? get token => _token;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _token != null;
  bool get isTeacher => _currentUser?.isTeacher ?? false;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  

  Future<User> register(
    String email,
    String password,
    String name,
    bool isTeacher,
  ) async {
    final resp = await http
        .post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
            'name': name,
            'is_teacher': isTeacher,
          }),
        )
        .timeout(_requestTimeout);
    if (resp.statusCode != 201) {
      throw ApiException(_parseError(resp.body));
    }
    final data = jsonDecode(resp.body);
    await _setSessionFromResponse(data);
    return _currentUser!;
  }

  Future<User> login(String email, String password) async {
    late http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw ApiException(
        'Сервер не отвечает (таймаут). Проверьте бэкенд и сеть.',
      );
    }
    if (resp.statusCode != 200) {
      throw ApiException(_parseError(resp.body));
    }
    final data = jsonDecode(resp.body);
    await _setSessionFromResponse(data);
    return _currentUser!;
  }

  void logout() {
    _token = null;
    _currentUser = null;
    unawaited(_clearPersistedSession());
  }

  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (token == null || userJson == null) {
      return false;
    }

    try {
      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      _token = token;
      _currentUser = User.fromJson(userMap);
      return true;
    } catch (_) {
      await _clearPersistedSession();
      return false;
    }
  }

  

  Future<List<Assignment>> getAssignments() async {
    final resp = await http
        .get(Uri.parse('$baseUrl/assignments'), headers: _headers)
        .timeout(_requestTimeout);
    if (resp.statusCode != 200) throw ApiException(_parseError(resp.body));
    final List data = jsonDecode(resp.body);
    return data.map((j) => Assignment.fromJson(j)).toList();
  }

  Future<Assignment> getAssignment(int id) async {
    final resp = await http
        .get(Uri.parse('$baseUrl/assignments/$id'), headers: _headers)
        .timeout(_requestTimeout);
    if (resp.statusCode != 200) throw ApiException(_parseError(resp.body));
    return Assignment.fromJson(jsonDecode(resp.body));
  }

  Future<Assignment> createAssignment(
    String title,
    String description,
    List<Map<String, dynamic>> criteria,
    List<int> groupIds,
  ) async {
    final resp = await http
        .post(
          Uri.parse('$baseUrl/assignments'),
          headers: _headers,
          body: jsonEncode({
            'title': title,
            'description': description,
            'criteria': criteria,
            'group_ids': groupIds,
          }),
        )
        .timeout(_requestTimeout);
    if (resp.statusCode != 201) throw ApiException(_parseError(resp.body));
    return Assignment.fromJson(jsonDecode(resp.body));
  }

  Future<Assignment> updateAssignment(
    int id,
    String title,
    String description,
    List<Map<String, dynamic>> criteria,
    List<int> groupIds,
  ) async {
    final resp = await http
        .put(
          Uri.parse('$baseUrl/assignments/$id'),
          headers: _headers,
          body: jsonEncode({
            'title': title,
            'description': description,
            'criteria': criteria,
            'group_ids': groupIds,
          }),
        )
        .timeout(_requestTimeout);
    if (resp.statusCode != 200) throw ApiException(_parseError(resp.body));
    return Assignment.fromJson(jsonDecode(resp.body));
  }

  

  Future<List<Group>> getMyGroups() async {
    final resp = await http
        .get(Uri.parse('$baseUrl/groups'), headers: _headers)
        .timeout(_requestTimeout);
    if (resp.statusCode != 200) throw ApiException(_parseError(resp.body));
    final List data = jsonDecode(resp.body);
    return data.map((j) => Group.fromJson(j)).toList();
  }

  Future<Group> createGroup(String name, List<String> studentEmails) async {
    final resp = await http
        .post(
          Uri.parse('$baseUrl/groups'),
          headers: _headers,
          body: jsonEncode({'name': name, 'student_emails': studentEmails}),
        )
        .timeout(_requestTimeout);
    if (resp.statusCode != 201) throw ApiException(_parseError(resp.body));
    return Group.fromJson(jsonDecode(resp.body));
  }

  Future<Group> addStudentsToGroup(
    int groupId,
    List<String> studentEmails,
  ) async {
    final resp = await http
        .post(
          Uri.parse('$baseUrl/groups/$groupId/students'),
          headers: _headers,
          body: jsonEncode({'student_emails': studentEmails}),
        )
        .timeout(_requestTimeout);
    if (resp.statusCode != 200) throw ApiException(_parseError(resp.body));
    return Group.fromJson(jsonDecode(resp.body));
  }

  

  Future<Submission> submitAssignment(
    int assignmentId,
    String githubRepo,
  ) async {
    final resp = await http
        .post(
          Uri.parse('$baseUrl/assignments/$assignmentId/submit'),
          headers: _headers,
          body: jsonEncode({'github_repo': githubRepo}),
        )
        .timeout(_requestTimeout);
    if (resp.statusCode != 201) throw ApiException(_parseError(resp.body));
    return Submission.fromJson(jsonDecode(resp.body));
  }

  Future<void> startReview(int submissionId) async {
    final resp = await http
        .post(
          Uri.parse('$baseUrl/submissions/$submissionId/review'),
          headers: _headers,
        )
        .timeout(_requestTimeout);
    if (resp.statusCode != 202) throw ApiException(_parseError(resp.body));
  }

  Future<Submission> getSubmissionResults(int submissionId) async {
    final resp = await http
        .get(
          Uri.parse('$baseUrl/submissions/$submissionId/results'),
          headers: _headers,
        )
        .timeout(_requestTimeout);
    if (resp.statusCode != 200) throw ApiException(_parseError(resp.body));
    return Submission.fromJson(jsonDecode(resp.body));
  }

  Future<List<Submission>> getMySubmissions() async {
    final resp = await http
        .get(Uri.parse('$baseUrl/my/submissions'), headers: _headers)
        .timeout(_requestTimeout);
    if (resp.statusCode != 200) throw ApiException(_parseError(resp.body));
    final List data = jsonDecode(resp.body);
    return data.map((j) => Submission.fromJson(j)).toList();
  }

  Future<List<GitHubRepoFile>> getSubmissionFiles(int submissionId) async {
    late http.Response resp;
    try {
      resp = await http
          .get(
            Uri.parse('$baseUrl/submissions/$submissionId/files'),
            headers: _headers,
          )
          .timeout(_filesRequestTimeout);
    } on TimeoutException {
      throw ApiException(
        'Загрузка файлов заняла слишком много времени. Попробуйте снова через несколько секунд.',
      );
    }
    if (resp.statusCode != 200) throw ApiException(_parseError(resp.body));
    final List data = jsonDecode(resp.body);
    return data.map((j) => GitHubRepoFile.fromJson(j)).toList();
  }

  Future<GitHubDeviceStart> startGithubDeviceFlow(bool isTeacher) async {
    final resp = await http
        .post(
          Uri.parse('$baseUrl/auth/github/device/start'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'is_teacher': isTeacher}),
        )
        .timeout(_requestTimeout);
    if (resp.statusCode != 200) throw ApiException(_parseError(resp.body));
    return GitHubDeviceStart.fromJson(jsonDecode(resp.body));
  }

  Future<GitHubDevicePollResult> pollGithubDeviceFlow(String deviceCode) async {
    final resp = await http
        .post(
          Uri.parse('$baseUrl/auth/github/device/poll'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'device_code': deviceCode}),
        )
        .timeout(_requestTimeout);

    if (resp.statusCode == 202) {
      return GitHubDevicePollResult(pending: true);
    }

    if (resp.statusCode != 200) {
      throw ApiException(_parseError(resp.body));
    }

    final data = jsonDecode(resp.body);
    await _setSessionFromResponse(data);
    return GitHubDevicePollResult(pending: false);
  }

  Future<void> _setSessionFromResponse(Map<String, dynamic> data) async {
    _token = data['token'];
    _currentUser = User.fromJson(data['user']);
    await _persistSession();
  }

  Future<void> _persistSession() async {
    if (_token == null || _currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
    await prefs.setString(
      _userKey,
      jsonEncode({
        'id': _currentUser!.id,
        'email': _currentUser!.email,
        'name': _currentUser!.name,
        'is_teacher': _currentUser!.isTeacher,
      }),
    );
  }

  Future<void> _clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  String _parseError(String body) {
    try {
      return jsonDecode(body)['error'] ?? 'Unknown error';
    } catch (_) {
      return body;
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
