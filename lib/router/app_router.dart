import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../cubits/cubits.dart';
import '../models/models.dart';
import '../screens/screens.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter createAppRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/assignments',
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      final authState = authCubit.state;
      final isGoingToLoginOrRegister =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isGoingToGithubBind = state.matchedLocation == '/github-bind';
      final isGoingToJoinGroup = state.matchedLocation.startsWith(
        '/groups/join',
      );

      if (authState is AuthInitial) {
        // ждём инициализацию
        return null;
      }

      final isAuth = authState is AuthAuthenticated;
      final isBindRequired = authState is AuthGithubBindRequired;

      if (isBindRequired && !isGoingToGithubBind) return '/github-bind';
      if (!isAuth &&
          !isBindRequired &&
          !isGoingToLoginOrRegister &&
          !isGoingToJoinGroup)
        return '/login';
      if (isAuth && isGoingToLoginOrRegister) return '/assignments';

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/github-bind',
        builder: (context, state) => const GitHubBindScreen(),
      ),
      GoRoute(
        path: '/assignments',
        builder: (context, state) => const AssignmentsListScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) => CreateAssignmentScreen(
              onCreated: () => context.go('/assignments'),
              onBack: () => context.go('/assignments'),
            ),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              final assignment = state.extra as Assignment?;
              return CreateAssignmentScreen(
                editAssignment: assignment,
                onCreated: () => context.go('/assignments/$id'),
                onBack: () => context.go('/assignments/$id'),
              );
            },
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return AssignmentDetailScreen(
                assignmentId: id,
                onBack: () => context.go('/assignments'),
                onViewFiles: (subId) =>
                    context.go('/assignments/$id/submissions/$subId/files'),
                onViewResults: (subId) =>
                    context.go('/assignments/$id/submissions/$subId/results'),
                onEdit: (assignment) => context.go(
                  '/assignments/edit/${assignment.id}',
                  extra: assignment,
                ),
              );
            },
          ),
          GoRoute(
            path: ':id/submissions/:subId/files',
            builder: (context, state) {
              final subId = int.parse(state.pathParameters['subId']!);
              final id = int.parse(state.pathParameters['id']!);
              return SubmissionFilesScreen(
                submissionId: subId,
                onBack: () => context.go('/assignments/$id'),
              );
            },
          ),
          GoRoute(
            path: ':id/submissions/:subId/results',
            builder: (context, state) {
              final subId = int.parse(state.pathParameters['subId']!);
              final id = int.parse(state.pathParameters['id']!);
              return ReviewResultsScreen(
                submissionId: subId,
                onBack: () => context.go('/assignments/$id'),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/groups',
        builder: (context, state) =>
            GroupsScreen(onBack: () => context.go('/assignments')),
      ),
      GoRoute(
        path: '/groups/join/:code',
        builder: (context, state) {
          final inviteCode = state.pathParameters['code']!;
          return GroupJoinScreen(inviteCode: inviteCode);
        },
      ),
    ],
  );
}
