import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/notifications/notification_registration_service.dart';
import '../services/auth_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authenticatedBuilder,
    required this.unauthenticatedBuilder,
  });

  final WidgetBuilder authenticatedBuilder;
  final WidgetBuilder unauthenticatedBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();

  final NotificationRegistrationService _notificationRegistrationService =
      NotificationRegistrationService.instance;

  User? _lastRegisteredUser;

  @override
  void dispose() {
    _notificationRegistrationService.dispose();
    super.dispose();
  }

  Future<void> _registerNotifications(User user) async {
    if (_lastRegisteredUser?.uid == user.uid) {
      return;
    }

    _lastRegisteredUser = user;

    await _notificationRegistrationService.initializeForUser(uid: user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          _lastRegisteredUser = null;

          return widget.unauthenticatedBuilder(context);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }

          _registerNotifications(user);
        });

        return widget.authenticatedBuilder(context);
      },
    );
  }
}
