import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/models.dart';
import '../repositories/submission_repository.dart';
import 'submission_files_state.dart';

class SubmissionFilesCubit extends Cubit<SubmissionFilesState> {
  final SubmissionRepository submissionRepository;

  SubmissionFilesCubit(this.submissionRepository)
    : super(SubmissionFilesInitial());

  Future<void> loadFiles(int submissionId) async {
    emit(SubmissionFilesLoading());
    try {
      final files = await submissionRepository.getSubmissionFiles(submissionId);
      files.sort(
        (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
      );

      final filesByPath = {for (final f in files) f.path: f};
      final root = _buildTree(files);

      List<ReviewFinding> allFindings = [];
      try {
        final submission = await submissionRepository.getSubmissionResults(
          submissionId,
        );
        allFindings = submission.findings;
      } catch (_) {
        // игнорируем ошибки загрузки результатов, если хотя бы файлы скачались
      }

      emit(
        SubmissionFilesLoaded(
          files: files,
          filesByPath: filesByPath,
          findings: allFindings,
          root: root,
        ),
      );
    } catch (e) {
      emit(SubmissionFilesError(e.toString()));
    }
  }

  FolderNode _buildTree(List<GitHubRepoFile> files) {
    final root = FolderNode(name: '', path: '');

    for (final file in files) {
      final normalized = file.path.replaceAll('\\', '/');
      final parts = normalized.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.isEmpty) continue;

      var current = root;
      for (var i = 0; i < parts.length - 1; i++) {
        final dirName = parts[i];
        final dirPath = current.path.isEmpty
            ? dirName
            : '${current.path}/$dirName';
        current = current.folders.putIfAbsent(
          dirName,
          () => FolderNode(name: dirName, path: dirPath),
        );
      }

      current.files.add(normalized);
    }

    _sortTree(root);
    return root;
  }

  void _sortTree(FolderNode node) {
    for (final child in node.folders.values) {
      _sortTree(child);
    }

    node.files.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }
}
