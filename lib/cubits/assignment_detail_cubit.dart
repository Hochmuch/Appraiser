import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/models.dart';
import '../repositories/assignment_repository.dart';
import '../repositories/submission_repository.dart';

class AssignmentDetailState {
  final Assignment? assignment;
  final bool isLoading;
  final String? error;

  final bool isSubmitting;
  final String? submitInfoMsg;
  final String? submitError;

  final bool isStartingReview;
  final String? reviewActionMsg;
  final String? reviewError;

  const AssignmentDetailState({
    this.assignment,
    this.isLoading = false,
    this.error,
    this.isSubmitting = false,
    this.submitInfoMsg,
    this.submitError,
    this.isStartingReview = false,
    this.reviewActionMsg,
    this.reviewError,
  });

  AssignmentDetailState copyWith({
    Assignment? assignment,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isSubmitting,
    String? submitInfoMsg,
    bool clearSubmitInfoMsg = false,
    String? submitError,
    bool clearSubmitError = false,
    bool? isStartingReview,
    String? reviewActionMsg,
    bool clearReviewActionMsg = false,
    String? reviewError,
    bool clearReviewError = false,
  }) {
    return AssignmentDetailState(
      assignment: assignment ?? this.assignment,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitInfoMsg: clearSubmitInfoMsg
          ? null
          : (submitInfoMsg ?? this.submitInfoMsg),
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
      isStartingReview: isStartingReview ?? this.isStartingReview,
      reviewActionMsg: clearReviewActionMsg
          ? null
          : (reviewActionMsg ?? this.reviewActionMsg),
      reviewError: clearReviewError ? null : (reviewError ?? this.reviewError),
    );
  }
}

class AssignmentDetailCubit extends Cubit<AssignmentDetailState> {
  final AssignmentRepository assignmentRepository;
  final SubmissionRepository submissionRepository;
  final int assignmentId;

  Timer? _pollingTimer;
  bool _pollRequestInFlight = false;

  AssignmentDetailCubit({
    required this.assignmentRepository,
    required this.submissionRepository,
    required this.assignmentId,
  }) : super(const AssignmentDetailState()) {
    loadAssignment();
  }

  @override
  Future<void> close() {
    _pollingTimer?.cancel();
    return super.close();
  }

  Future<void> loadAssignment({bool showLoading = true}) async {
    if (showLoading) {
      emit(state.copyWith(isLoading: true, clearError: true));
    }

    try {
      final a = await assignmentRepository.getAssignment(assignmentId);

      final hadReviewingSubmission =
          state.assignment?.submissions?.any((s) => s.status == 'reviewing') ??
          false;
      final hasReviewingSubmission =
          a.submissions?.any((s) => s.status == 'reviewing') ?? false;

      String? reviewMsg = state.reviewActionMsg;
      if (hadReviewingSubmission && !hasReviewingSubmission) {
        reviewMsg = 'Проверка завершена. Результаты обновлены.';
      }

      emit(
        state.copyWith(
          assignment: a,
          isLoading: false,
          reviewActionMsg: reviewMsg,
        ),
      );

      _syncReviewPolling(hasReviewingSubmission);
    } catch (e) {
      if (showLoading) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    }
  }

  void _syncReviewPolling(bool shouldPoll) {
    if (!shouldPoll) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
      return;
    }

    if (_pollingTimer != null) return;

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (isClosed || _pollRequestInFlight) return;
      _pollRequestInFlight = true;
      try {
        await loadAssignment(showLoading: false);
      } finally {
        _pollRequestInFlight = false;
      }
    });
  }

  Future<void> submitRepository(String githubRepo) async {
    if (githubRepo.isEmpty) return;

    emit(
      state.copyWith(
        isSubmitting: true,
        clearSubmitError: true,
        clearSubmitInfoMsg: true,
      ),
    );
    try {
      await submissionRepository.submitAssignment(assignmentId, githubRepo);
      emit(
        state.copyWith(
          isSubmitting: false,
          submitInfoMsg: 'Работа отправлена!',
        ),
      );
      await loadAssignment(showLoading: false);
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, submitError: 'Ошибка: $e'));
    }
  }

  Future<void> startReview(
    int submissionId,
    String provider,
    String model,
  ) async {
    emit(
      state.copyWith(
        isStartingReview: true,
        clearReviewError: true,
        clearReviewActionMsg: true,
      ),
    );
    try {
      await submissionRepository.startReview(
        submissionId,
        llmProvider: provider,
        llmModel: model,
      );
      emit(
        state.copyWith(
          isStartingReview: false,
          reviewActionMsg: 'Проверка запущена!',
        ),
      );
      _syncReviewPolling(true);
      await loadAssignment(showLoading: false);
    } catch (e) {
      emit(state.copyWith(isStartingReview: false, reviewError: 'Ошибка: $e'));
    }
  }

  void clearMessages() {
    emit(
      state.copyWith(
        clearSubmitInfoMsg: true,
        clearSubmitError: true,
        clearReviewActionMsg: true,
        clearReviewError: true,
      ),
    );
  }
}
