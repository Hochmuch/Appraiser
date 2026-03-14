import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';

class LoginScreen extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback onLoginSuccess;
  final VoidCallback onGoToRegister;

  const LoginScreen({
    super.key,
    required this.apiClient,
    required this.onLoginSuccess,
    required this.onGoToRegister,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _githubLoading = false;
  String? _githubUserCode;
  String? _githubVerificationUri;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.apiClient.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      widget.onLoginSuccess();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Ошибка подключения к серверу');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGithub(bool isTeacher) async {
    setState(() {
      _githubLoading = true;
      _error = null;
      _githubUserCode = null;
      _githubVerificationUri = null;
    });

    try {
      final start = await widget.apiClient.startGithubDeviceFlow(isTeacher);

      setState(() {
        _githubUserCode = start.userCode;
        _githubVerificationUri = start.verificationUri;
      });

      final uri = Uri.parse(start.verificationUri);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Не удалось открыть браузер для GitHub OAuth');
      }

      final startedAt = DateTime.now();
      final timeoutAt = startedAt.add(Duration(seconds: start.expiresIn));
      final interval = Duration(seconds: start.interval.clamp(2, 10));

      while (DateTime.now().isBefore(timeoutAt)) {
        await Future.delayed(interval);
        late final poll;
        try {
          poll = await widget.apiClient.pollGithubDeviceFlow(start.deviceCode);
        } on TimeoutException {
          continue;
        } on http.ClientException {
          continue;
        } catch (e) {
          final msg = e.toString();
          if (msg.contains('Software caused connection abort') ||
              msg.contains('Future not completed')) {
            continue;
          }
          rethrow;
        }
        if (!poll.pending) {
          if (!mounted) return;
          widget.onLoginSuccess();
          return;
        }
      }

      throw ApiException(
        'Время подтверждения GitHub OAuth истекло. Повтори вход.',
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Ошибка GitHub OAuth: $e');
    } finally {
      if (mounted) {
        setState(() {
          _githubLoading = false;
        });
      }
    }
  }

  Future<void> _chooseGithubRoleAndLogin() async {
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

    if (role == null) return;
    await _loginWithGithub(role == 'teacher');
  }

  @override
  Widget build(BuildContext context) {
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
                  onSubmitted: (_) => _login(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Войти'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _githubLoading ? null : _chooseGithubRoleAndLogin,
                  icon: _githubLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.code),
                  label: const Text('Войти через GitHub'),
                ),
                if (_githubLoading && _githubUserCode != null) ...[
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
                            _githubUserCode!,
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
                                    ClipboardData(text: _githubUserCode!),
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Код скопирован'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy),
                                label: const Text('Скопировать код'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _githubVerificationUri == null
                                    ? null
                                    : () async {
                                        final uri = Uri.parse(
                                          _githubVerificationUri!,
                                        );
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      },
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Открыть GitHub'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: widget.onGoToRegister,
                  child: const Text('Нет аккаунта? Зарегистрироваться'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
