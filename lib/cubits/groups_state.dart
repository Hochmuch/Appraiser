import '../models/models.dart';

abstract class GroupsState {}

class GroupsInitial extends GroupsState {}

class GroupsLoading extends GroupsState {}

class GroupsLoaded extends GroupsState {
  final List<Group> groups;
  final bool isCreating;
  final String? actionError;
  final String? actionMessage;

  GroupsLoaded({
    required this.groups,
    this.isCreating = false,
    this.actionError,
    this.actionMessage,
  });

  GroupsLoaded copyWith({
    List<Group>? groups,
    bool? isCreating,
    String? actionError,
    String? actionMessage,
    bool clearActionError = false,
    bool clearActionMessage = false,
  }) {
    return GroupsLoaded(
      groups: groups ?? this.groups,
      isCreating: isCreating ?? this.isCreating,
      actionError: clearActionError ? null : (actionError ?? this.actionError),
      actionMessage: clearActionMessage
          ? null
          : (actionMessage ?? this.actionMessage),
    );
  }
}

class GroupsError extends GroupsState {
  final String message;
  GroupsError(this.message);
}
