import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/assignment_repository.dart';
import 'assignments_state.dart';

class AssignmentsCubit extends Cubit<AssignmentsState> {
  final AssignmentRepository assignmentRepository;

  AssignmentsCubit(this.assignmentRepository) : super(AssignmentsInitial());

  Future<void> loadAssignments() async {
    emit(AssignmentsLoading());
    try {
      final assignments = await assignmentRepository.getAssignments();
      emit(AssignmentsLoaded(assignments));
    } catch (e) {
      emit(AssignmentsError(e.toString()));
    }
  }
}
