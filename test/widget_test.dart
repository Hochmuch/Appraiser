import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appraiser/main.dart';
import 'package:appraiser/repositories/assignment_repository.dart';
import 'package:appraiser/repositories/auth_repository.dart';
import 'package:appraiser/repositories/group_repository.dart';
import 'package:appraiser/repositories/submission_repository.dart';
import 'package:appraiser/services/api_client.dart';

void main() {
  testWidgets('App boots', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final apiClient = ApiClient();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ApiClient>.value(value: apiClient),
          RepositoryProvider<AuthRepository>.value(
            value: AuthRepository(apiClient),
          ),
          RepositoryProvider<AssignmentRepository>.value(
            value: AssignmentRepository(apiClient),
          ),
          RepositoryProvider<GroupRepository>.value(
            value: GroupRepository(apiClient),
          ),
          RepositoryProvider<SubmissionRepository>.value(
            value: SubmissionRepository(apiClient),
          ),
        ],
        child: const AppraiserApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
