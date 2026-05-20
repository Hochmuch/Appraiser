import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/models.dart';
import '../repositories/assignment_repository.dart';
import '../repositories/group_repository.dart';
import '../services/api_client.dart';
import 'create_assignment_state.dart';

class CreateAssignmentCubit extends Cubit<CreateAssignmentState> {
  final AssignmentRepository assignmentRepository;
  final GroupRepository groupRepository;
  List<Group> _cachedGroups = [];

  CreateAssignmentCubit(
    this.assignmentRepository,
    this.groupRepository,
  ) : super(CreateAssignmentInitial()) {
    loadGroups();
  }

  Future<void> loadGroups() async {
    emit(CreateAssignmentLoadingGroups());
    try {
      _cachedGroups = await groupRepository.getMyGroups();
      emit(CreateAssignmentGroupsLoaded(_cachedGroups));
    } on ApiException catch (e) {
      emit(CreateAssignmentGroupsError(e.message));
    } catch (e) {
      emit(CreateAssignmentGroupsError('Ошибка загрузки групп: $e'));
    }
  }

  Future<void> submit(
    bool isEditing,
    Assignment? editAssignment,
    String title,
    String description,
    List<Map<String, dynamic>> criteria,
    List<int> selectedGroupIds,
  ) async {
    if (title.isEmpty) {
      emit(CreateAssignmentError(_cachedGroups, 'Введите название'));
      return;
    }
    if (criteria.isEmpty) {
      emit(
        CreateAssignmentError(_cachedGroups, 'Добавьте хотя бы один критерий'),
      );
      return;
    }
    if (selectedGroupIds.isEmpty) {
      emit(
        CreateAssignmentError(_cachedGroups, 'Выберите хотя бы одну группу'),
      );
      return;
    }

    emit(CreateAssignmentSubmitting(_cachedGroups));

    try {
      if (isEditing) {
        await assignmentRepository.updateAssignment(
          editAssignment!.id,
          title,
          description,
          criteria,
          selectedGroupIds,
        );
      } else {
        await assignmentRepository.createAssignment(
          title,
          description,
          criteria,
          selectedGroupIds,
        );
      }
      emit(CreateAssignmentSuccess());
    } on ApiException catch (e) {
      emit(CreateAssignmentError(_cachedGroups, e.message));
    } catch (e) {
      emit(CreateAssignmentError(_cachedGroups, 'Ошибка: $e'));
    }
  }
}
