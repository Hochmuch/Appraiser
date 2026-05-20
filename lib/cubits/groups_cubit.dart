import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/group_repository.dart';
import '../services/api_client.dart';
import 'groups_state.dart';

class GroupsCubit extends Cubit<GroupsState> {
  final GroupRepository groupRepository;

  GroupsCubit(this.groupRepository) : super(GroupsInitial());

  Future<void> loadGroups({bool showLoading = true}) async {
    if (showLoading) {
      emit(GroupsLoading());
    }

    try {
      final groups = await groupRepository.getMyGroups();

      if (state is GroupsLoaded) {
        emit((state as GroupsLoaded).copyWith(groups: groups));
      } else {
        emit(GroupsLoaded(groups: groups));
      }
    } catch (e) {
      final errorMsg = e is ApiException ? e.message : e.toString();
      emit(GroupsError(errorMsg));
    }
  }

  Future<void> createGroup(String name, String emailsText) async {
    if (state is! GroupsLoaded) return;
    final currentState = state as GroupsLoaded;

    if (name.isEmpty) {
      emit(currentState.copyWith(actionError: 'Введите название группы'));
      return;
    }

    final emails = emailsText
        .split(RegExp(r'[\n,;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    emit(currentState.copyWith(isCreating: true, clearActionError: true));
    try {
      await groupRepository.createGroup(name, emails);
      emit(
        currentState.copyWith(
          isCreating: false,
          actionMessage: 'Группа успешно создана',
        ),
      );
      loadGroups(showLoading: false);
    } catch (e) {
      final errorMsg = e is ApiException ? e.message : e.toString();
      emit(currentState.copyWith(isCreating: false, actionError: errorMsg));
    }
  }

  Future<void> addStudentsToGroup(int groupId, String emailsText) async {
    if (state is! GroupsLoaded) return;
    final currentState = state as GroupsLoaded;

    final emails = emailsText
        .split(RegExp(r'[\n,;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (emails.isEmpty) {
      emit(currentState.copyWith(actionError: 'Введите хотя бы один email'));
      return;
    }

    emit(currentState.copyWith(isCreating: true, clearActionError: true));
    try {
      await groupRepository.addStudentsToGroup(groupId, emails);
      emit(
        currentState.copyWith(
          isCreating: false,
          actionMessage: 'Студенты успешно добавлены',
        ),
      );
      loadGroups(showLoading: false);
    } catch (e) {
      final errorMsg = e is ApiException ? e.message : e.toString();
      emit(currentState.copyWith(isCreating: false, actionError: errorMsg));
    }
  }

  void clearMessages() {
    if (state is GroupsLoaded) {
      final currentState = state as GroupsLoaded;
      if (currentState.actionError != null ||
          currentState.actionMessage != null) {
        emit(
          currentState.copyWith(
            clearActionError: true,
            clearActionMessage: true,
          ),
        );
      }
    }
  }
}
