import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cubits/auth_cubit.dart';
import '../cubits/auth_state.dart';

class GitHubBindScreen extends StatefulWidget {
  const GitHubBindScreen({super.key});

  @override
  State<GitHubBindScreen> createState() => _GitHubBindScreenState();
}

class _GitHubBindScreenState extends State<GitHubBindScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthGithubLoading;
        final isPrompt = state is AuthGithubPrompt;
        final user = state is AuthGithubBindRequired ? state.user : null;
        final githubUserCode = state is AuthGithubPrompt
            ? state.userCode
            : null;
        final verificationUri = state is AuthGithubPrompt
            ? state.verificationUri
            : null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Привязка GitHub'),
            automaticallyImplyLeading: false,
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.link, size: 80),
                    const SizedBox(height: 16),
                    const Text(
                      'Осталось привязать GitHub',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Этот шаг нужен для завершения регистрации и доступа к системе.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (user != null) ...[
                      Text('Email: ${user.email}'),
                      const SizedBox(height: 8),
                      Text(
                        'Роль: ${user.isTeacher ? 'Преподаватель' : 'Студент'}',
                      ),
                      const SizedBox(height: 20),
                    ],
                    FilledButton(
                      onPressed: isLoading || isPrompt || user == null
                          ? null
                          : () => context.read<AuthCubit>().loginWithGithub(
                              user.isTeacher,
                              user.email,
                            ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Привязать GitHub'),
                    ),
                    const SizedBox(height: 16),
                    if (isPrompt &&
                        githubUserCode != null &&
                        verificationUri != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Перейдите в GitHub и введите код:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                githubUserCode,
                                style: const TextStyle(
                                  fontSize: 20,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: githubUserCode),
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
                                      final uri = Uri.parse(verificationUri);
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.open_in_browser,
                                      size: 18,
                                    ),
                                    label: const Text('Открыть GitHub'),
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
