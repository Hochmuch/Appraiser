import '../models/models.dart';
import '../services/api_client.dart';

class GroupRepository {
  final ApiClient _apiClient;

  GroupRepository(this._apiClient);

  Future<List<Group>> getMyGroups() {
    return _apiClient.getMyGroups();
  }

  Future<Group> createGroup(String name, List<String> studentEmails) {
    return _apiClient.createGroup(name, studentEmails);
  }

  Future<Group> joinGroupByInviteCode(String inviteCode) {
    return _apiClient.joinGroupByInviteCode(inviteCode);
  }

  Future<Group> addStudentsToGroup(int groupId, List<String> studentEmails) {
    return _apiClient.addStudentsToGroup(groupId, studentEmails);
  }
}
