import 'package:flutter/material.dart';
import '../services/api_client.dart';

class RegisterScreen extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback onRegisterSuccess;
  final VoidCallback onGoToLogin;

  const RegisterScreen({
    super.key,
    required this.apiClient,
    required this.onRegisterSuccess,
    required this.onGoToLogin,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isTeacher = false;
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.apiClient.register(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
        _isTeacher,
      );
      widget.onRegisterSuccess();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Ошибка подключения к серверу');
    } finally {
      setState(() => _loading = false);
    }
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
                Icon(Icons.person_add, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Регистрация',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Имя',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
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
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Я преподаватель'),
                  subtitle: const Text('Студенты не могут создавать задания'),
                  value: _isTeacher,
                  onChanged: (v) => setState(() => _isTeacher = v),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Зарегистрироваться'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: widget.onGoToLogin,
                  child: const Text('Уже есть аккаунт? Войти'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
