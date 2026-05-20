import '../models/models.dart';
import '../services/api_client.dart';

class SubmissionRepository {
  final ApiClient _apiClient;

  SubmissionRepository(this._apiClient);

  Future<Submission> submitAssignment(int assignmentId, String githubRepo) {
    return _apiClient.submitAssignment(assignmentId, githubRepo);
  }

  Future<void> startReview(
    int submissionId, {
    String? llmProvider,
    String? llmModel,
  }) {
    return _apiClient.startReview(
      submissionId,
      llmProvider: llmProvider,
      llmModel: llmModel,
    );
  }

  Future<Submission> getSubmissionResults(int submissionId) {
    return _apiClient.getSubmissionResults(submissionId);
  }

  Future<List<Submission>> getMySubmissions() {
    return _apiClient.getMySubmissions();
  }

  Future<List<GitHubRepoFile>> getSubmissionFiles(int submissionId) {
    return _apiClient.getSubmissionFiles(submissionId);
  }
}
