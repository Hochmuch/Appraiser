import '../models/models.dart';
import '../services/api_client.dart';

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  User? get currentUser => _apiClient.currentUser;
  bool get isLoggedIn => _apiClient.isLoggedIn;
  bool get isTeacher => _apiClient.isTeacher;

  Future<User> register(
    String email,
    String password,
    String name,
    bool isTeacher,
  ) {
    return _apiClient.register(email, password, name, isTeacher);
  }

  Future<User> login(String email, String password) {
    return _apiClient.login(email, password);
  }

  Future<GitHubDeviceStart> startGithubDeviceFlow(
    bool isTeacher, [
    String? email,
  ]) {
    return _apiClient.startGithubDeviceFlow(isTeacher, email);
  }

  Future<GitHubDevicePollResult> pollGithubDeviceFlow(String deviceCode) {
    return _apiClient.pollGithubDeviceFlow(deviceCode);
  }

  Future<bool> restoreSession() {
    return _apiClient.restoreSession();
  }

  void logout() {
    _apiClient.logout();
  }
}
