import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cubits/auth_cubit.dart';
import '../cubits/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _chooseGithubRoleAndLogin(BuildContext context) async {
    final role = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Войти как студент'),
              onTap: () => Navigator.pop(context, 'student'),
            ),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text('Войти как преподаватель'),
              onTap: () => Navigator.pop(context, 'teacher'),
            ),
          ],
        ),
      ),
    );

    if (role == null || !context.mounted) return;
    context.read<AuthCubit>().loginWithGithub(role == 'teacher');
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
        if (state is AuthGithubBindRequired) {
          if (context.mounted) context.go('/github-bind');
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        final isGithubLoading =
            state is AuthGithubLoading || state is AuthGithubPrompt;
        String? githubUserCode;

        if (state is AuthGithubPrompt) {
          githubUserCode = state.userCode;
        }

        return Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.school,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Appraiser',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Система проверки домашних заданий',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        if (!isLoading && !isGithubLoading) {
                          context.read<AuthCubit>().login(
                            _emailController.text,
                            _passwordController.text,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: isLoading || isGithubLoading
                          ? null
                          : () => context.read<AuthCubit>().login(
                              _emailController.text,
                              _passwordController.text,
                            ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Войти'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: isLoading || isGithubLoading
                          ? null
                          : () => _chooseGithubRoleAndLogin(context),
                      icon: isGithubLoading && githubUserCode == null
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.code),
                      label: const Text('Войти через GitHub'),
                    ),
                    if (githubUserCode != null) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'В GitHub введи этот код:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                githubUserCode,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(letterSpacing: 1.4),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: githubUserCode!),
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Код скопирован'),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.copy, size: 18),
                                    label: const Text('Копировать код'),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () async {
                                      if (state is AuthGithubPrompt) {
                                        await launchUrl(
                                          Uri.parse(state.verificationUri),
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.open_in_browser,
                                      size: 18,
                                    ),
                                    label: const Text('Открыть браузер снова'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Ожидаем подтверждения в браузере...',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: isLoading || isGithubLoading
                          ? null
                          : () => context.go('/register'),
                      child: const Text('Нет аккаунта? Зарегистрируйтесь'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
