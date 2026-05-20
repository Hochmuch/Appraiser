import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../repositories/auth_repository.dart';
import '../services/api_client.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository authRepository;

  AuthCubit(this.authRepository) : super(AuthInitial());

  Future<void> checkSession() async {
    final restored = await authRepository.restoreSession();
    if (restored && authRepository.currentUser != null) {
      emit(AuthAuthenticated(authRepository.currentUser!));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  void logout() {
    authRepository.logout();
    emit(AuthUnauthenticated());
  }

  Future<void> login(String email, String password) async {
    emit(AuthLoading());

    try {
      await authRepository.login(email.trim(), password);
      final user = authRepository.currentUser!;
      if (user.githubId == null) {
        emit(AuthGithubBindRequired(user));
      } else {
        emit(AuthAuthenticated(user));
      }
    } on ApiException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError('Ошибка подключения к серверу: $e'));
    }
  }

  Future<void> register(
    String email,
    String password,
    String name,
    bool isTeacher,
  ) async {
    emit(AuthLoading());

    try {
      await authRepository.register(
        email.trim(),
        password,
        name.trim(),
        isTeacher,
      );
      final user = authRepository.currentUser!;
      if (user.githubId == null) {
        emit(AuthGithubBindRequired(user));
      } else {
        emit(AuthAuthenticated(user));
      }
    } on ApiException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError('Ошибка подключения к серверу: $e'));
    }
  }

  Future<void> loginWithGithub(bool isTeacher, [String? email]) async {
    emit(AuthGithubLoading());

    try {
      final start = await authRepository.startGithubDeviceFlow(
        isTeacher,
        email,
      );

      emit(AuthGithubPrompt(start.userCode, start.verificationUri));

      final uri = Uri.parse(start.verificationUri);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Не удалось открыть браузер для GitHub OAuth');
      }

      final startedAt = DateTime.now();
      final timeoutAt = startedAt.add(Duration(seconds: start.expiresIn));
      final interval = Duration(seconds: start.interval.clamp(2, 10));

      while (DateTime.now().isBefore(timeoutAt)) {
        await Future.delayed(interval);

        if (isClosed) return;

        late final GitHubDevicePollResult poll;
        try {
          poll = await authRepository.pollGithubDeviceFlow(start.deviceCode);
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
          if (!isClosed) emit(AuthAuthenticated(authRepository.currentUser!));
          return;
        }
      }

      if (!isClosed) {
        emit(
          AuthError('Время подтверждения GitHub OAuth истекло. Повтори вход.'),
        );
      }
    } on ApiException catch (e) {
      if (!isClosed) emit(AuthError(e.message));
    } catch (e) {
      if (!isClosed) emit(AuthError('Ошибка GitHub OAuth: $e'));
    }
  }
}
