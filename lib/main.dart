import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'repositories/repositories.dart';
import 'services/api_client.dart';
import 'cubits/cubits.dart';
import 'router/app_router.dart';

void main() {
  final apiClient = ApiClient();
  runApp(
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
      child: BlocProvider(
        create: (context) =>
            AuthCubit(context.read<AuthRepository>())..checkSession(),
        child: const AppraiserApp(),
      ),
    ),
  );
}

class AppraiserApp extends StatefulWidget {
  const AppraiserApp({super.key});

  @override
  State<AppraiserApp> createState() => _AppraiserAppState();
}

class _AppraiserAppState extends State<AppraiserApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authCubit = context.read<AuthCubit>();
    _router = createAppRouter(authCubit);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (previous, current) =>
          previous is AuthInitial && current is! AuthInitial,
      builder: (context, state) {
        if (state is AuthInitial) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final appDarkTheme = ThemeData(
          useMaterial3: true,
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
        );

        return MaterialApp.router(
          title: 'Appraiser',
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
          theme: appDarkTheme,
          darkTheme: appDarkTheme,
          themeMode: ThemeMode.dark,
        );
      },
    );
  }
}
