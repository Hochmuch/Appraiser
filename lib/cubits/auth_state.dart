import '../models/models.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

// Глобальные состояния аутентификации
class AuthAuthenticated extends AuthState {
  final User user;
  AuthAuthenticated(this.user);
}

class AuthGithubBindRequired extends AuthState {
  final User user;
  AuthGithubBindRequired(this.user);
}

class AuthUnauthenticated extends AuthState {}

// Состояния для процесса входа
class AuthGithubLoading extends AuthState {}

class AuthGithubPrompt extends AuthState {
  final String userCode;
  final String verificationUri;

  AuthGithubPrompt(this.userCode, this.verificationUri);
}

// Для успешного выполнения формы входа/регистрации
class AuthSuccess extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}
