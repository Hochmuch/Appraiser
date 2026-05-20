import '../models/models.dart';

abstract class AssignmentsState {}

class AssignmentsInitial extends AssignmentsState {}

class AssignmentsLoading extends AssignmentsState {}

class AssignmentsLoaded extends AssignmentsState {
  final List<Assignment> assignments;
  AssignmentsLoaded(this.assignments);
}

class AssignmentsError extends AssignmentsState {
  final String message;
  AssignmentsError(this.message);
}