import '../models/models.dart';

abstract class CreateAssignmentState {}

class CreateAssignmentInitial extends CreateAssignmentState {}

class CreateAssignmentLoadingGroups extends CreateAssignmentState {}

class CreateAssignmentGroupsLoaded extends CreateAssignmentState {
  final List<Group> groups;
  CreateAssignmentGroupsLoaded(this.groups);
}

class CreateAssignmentGroupsError extends CreateAssignmentState {
  final String message;
  CreateAssignmentGroupsError(this.message);
}

class CreateAssignmentSubmitting extends CreateAssignmentState {
  final List<Group> groups; // Держим список групп
  CreateAssignmentSubmitting(this.groups);
}

class CreateAssignmentSuccess extends CreateAssignmentState {}

class CreateAssignmentError extends CreateAssignmentState {
  final List<Group> groups;
  final String message;
  CreateAssignmentError(this.groups, this.message);
}
