import '../models/models.dart';
import '../services/api_client.dart';

class AssignmentRepository {
  final ApiClient _apiClient;

  AssignmentRepository(this._apiClient);

  Future<List<Assignment>> getAssignments() {
    return _apiClient.getAssignments();
  }

  Future<Assignment> getAssignment(int id) {
    return _apiClient.getAssignment(id);
  }

  Future<Assignment> createAssignment(
    String title,
    String description,
    List<Map<String, dynamic>> criteria,
    List<int> groupIds,
  ) {
    return _apiClient.createAssignment(title, description, criteria, groupIds);
  }

  Future<Assignment> updateAssignment(
    int id,
    String title,
    String description,
    List<Map<String, dynamic>> criteria,
    List<int> groupIds,
  ) {
    return _apiClient.updateAssignment(
      id,
      title,
      description,
      criteria,
      groupIds,
    );
  }
}
