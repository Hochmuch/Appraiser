import '../models/models.dart';

abstract class ReviewResultsState {}

class ReviewResultsInitial extends ReviewResultsState {}

class ReviewResultsLoading extends ReviewResultsState {}

class ReviewResultsLoaded extends ReviewResultsState {
  final Submission submission;
  ReviewResultsLoaded(this.submission);
}

class ReviewResultsError extends ReviewResultsState {
  final String message;
  ReviewResultsError(this.message);
}
