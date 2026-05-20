import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../repositories/group_repository.dart';
import '../models/models.dart';

class GroupJoinScreen extends StatefulWidget {
  final String inviteCode;

  const GroupJoinScreen({super.key, required this.inviteCode});

  @override
  State<GroupJoinScreen> createState() => _GroupJoinScreenState();
}

class _GroupJoinScreenState extends State<GroupJoinScreen> {
  bool _isJoining = false;
  String? _message;
  Group? _group;

  @override
  void initState() {
    super.initState();
    _joinGroup();
  }

  Future<void> _joinGroup() async {
    setState(() {
      _isJoining = true;
      _message = null;
    });

    try {
      final group = await context.read<GroupRepository>().joinGroupByInviteCode(
        widget.inviteCode,
      );

      setState(() {
        _group = group;
        _message = 'Вы успешно присоединились к группе «${group.name}».';
      });

      if (!mounted) {
        return;
      }

      context.go('/assignments');
    } catch (e) {
      setState(() {
        _message = e.toString();
      });
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Присоединение к группе')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Присоединение по ссылке',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Код приглашения: ${widget.inviteCode}'),
            const SizedBox(height: 16),
            if (_isJoining)
              const Center(child: CircularProgressIndicator())
            else if (_group != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_message ?? ''),
                  const SizedBox(height: 16),
                  Text('Группа: ${_group!.name}'),
                  Text('Студентов в группе: ${_group!.students.length}'),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_message != null) ...[
                    Text(_message!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    onPressed: _joinGroup,
                    child: const Text('Повторить присоединение'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
