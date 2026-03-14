import 'package:flutter/material.dart';
import 'models/models.dart';
import 'services/api_client.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/assignments_list_screen.dart';
import 'screens/create_assignment_screen.dart';
import 'screens/assignment_detail_screen.dart';
import 'screens/review_results_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/submission_files_screen.dart';

void main() {
  runApp(const AppraiserApp());
}

class AppraiserApp extends StatelessWidget {
  const AppraiserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Appraiser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          surface: Color(0xFF121212),
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
      ),
      themeMode: ThemeMode.dark,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

enum AppScreen {
  login,
  register,
  assignments,
  groups,
  createAssignment,
  editAssignment,
  assignmentDetail,
  submissionFiles,
  reviewResults,
}

class _AppShellState extends State<AppShell> {
  final _apiClient = ApiClient();
  bool _booting = true;
  AppScreen _screen = AppScreen.login;
  int? _selectedAssignmentId;
  int? _selectedSubmissionId;
  Assignment? _editingAssignment;

  @override
  void initState() {
    super.initState();
    _restoreAuthSession();
  }

  Future<void> _restoreAuthSession() async {
    final restored = await _apiClient.restoreSession();
    if (!mounted) return;
    setState(() {
      _screen = restored ? AppScreen.assignments : AppScreen.login;
      _booting = false;
    });
  }

  void _navigate(AppScreen screen, {int? assignmentId, int? submissionId}) {
    setState(() {
      _screen = screen;
      if (assignmentId != null) _selectedAssignmentId = assignmentId;
      if (submissionId != null) _selectedSubmissionId = submissionId;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    switch (_screen) {
      case AppScreen.login:
        return LoginScreen(
          apiClient: _apiClient,
          onLoginSuccess: () => _navigate(AppScreen.assignments),
          onGoToRegister: () => _navigate(AppScreen.register),
        );
      case AppScreen.register:
        return RegisterScreen(
          apiClient: _apiClient,
          onRegisterSuccess: () => _navigate(AppScreen.assignments),
          onGoToLogin: () => _navigate(AppScreen.login),
        );
      case AppScreen.assignments:
        return AssignmentsListScreen(
          apiClient: _apiClient,
          onAssignmentTap: (id) =>
              _navigate(AppScreen.assignmentDetail, assignmentId: id),
          onCreateAssignment: () => _navigate(AppScreen.createAssignment),
          onManageGroups: () => _navigate(AppScreen.groups),
          onLogout: () {
            _apiClient.logout();
            _navigate(AppScreen.login);
          },
        );
      case AppScreen.groups:
        return GroupsScreen(
          apiClient: _apiClient,
          onBack: () => _navigate(AppScreen.assignments),
        );
      case AppScreen.createAssignment:
        return CreateAssignmentScreen(
          apiClient: _apiClient,
          onCreated: () => _navigate(AppScreen.assignments),
          onBack: () => _navigate(AppScreen.assignments),
        );
      case AppScreen.editAssignment:
        return CreateAssignmentScreen(
          apiClient: _apiClient,
          editAssignment: _editingAssignment,
          onCreated: () => _navigate(
            AppScreen.assignmentDetail,
            assignmentId: _selectedAssignmentId,
          ),
          onBack: () => _navigate(
            AppScreen.assignmentDetail,
            assignmentId: _selectedAssignmentId,
          ),
        );
      case AppScreen.assignmentDetail:
        return AssignmentDetailScreen(
          apiClient: _apiClient,
          assignmentId: _selectedAssignmentId!,
          onBack: () => _navigate(AppScreen.assignments),
          onViewFiles: (submissionId) =>
              _navigate(AppScreen.submissionFiles, submissionId: submissionId),
          onViewResults: (submissionId) =>
              _navigate(AppScreen.reviewResults, submissionId: submissionId),
          onEdit: (assignment) {
            _editingAssignment = assignment;
            _navigate(AppScreen.editAssignment, assignmentId: assignment.id);
          },
        );
      case AppScreen.submissionFiles:
        return SubmissionFilesScreen(
          apiClient: _apiClient,
          submissionId: _selectedSubmissionId!,
          onBack: () => _navigate(
            AppScreen.assignmentDetail,
            assignmentId: _selectedAssignmentId,
          ),
        );
      case AppScreen.reviewResults:
        return ReviewResultsScreen(
          apiClient: _apiClient,
          submissionId: _selectedSubmissionId!,
          onBack: () => _navigate(
            AppScreen.assignmentDetail,
            assignmentId: _selectedAssignmentId,
          ),
        );
    }
  }
}
