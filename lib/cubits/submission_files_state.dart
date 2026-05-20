import '../models/models.dart';

class FolderNode {
  final String name;
  final String path;
  final Map<String, FolderNode> folders = {};
  final List<String> files = [];

  FolderNode({required this.name, required this.path});
}

abstract class SubmissionFilesState {}

class SubmissionFilesInitial extends SubmissionFilesState {}

class SubmissionFilesLoading extends SubmissionFilesState {}

class SubmissionFilesLoaded extends SubmissionFilesState {
  final List<GitHubRepoFile> files;
  final Map<String, GitHubRepoFile> filesByPath;
  final List<ReviewFinding> findings;
  final FolderNode root;

  SubmissionFilesLoaded({
    required this.files,
    required this.filesByPath,
    required this.findings,
    required this.root,
  });
}

class SubmissionFilesError extends SubmissionFilesState {
  final String message;
  SubmissionFilesError(this.message);
}
