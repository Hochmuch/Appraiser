import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/submission_repository.dart';
import 'review_results_state.dart';

class ReviewResultsCubit extends Cubit<ReviewResultsState> {
  final SubmissionRepository submissionRepository;

  ReviewResultsCubit(this.submissionRepository) : super(ReviewResultsInitial());

  Future<void> loadResults(int submissionId) async {
    emit(ReviewResultsLoading());
    try {
      final s = await submissionRepository.getSubmissionResults(submissionId);
      emit(ReviewResultsLoaded(s));
    } catch (e) {
      emit(ReviewResultsError(e.toString()));
    }
  }
}
