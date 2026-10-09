import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/notifications/notification_registration_service.dart';
import '../services/auth_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authenticatedBuilder,
    required this.unauthenticatedBuilder,
    this.authService,
    this.notificationRegistrationService,
  });

  final WidgetBuilder authenticatedBuilder;
  final WidgetBuilder unauthenticatedBuilder;
  final AuthService? authService;
  final NotificationRegistrationService? notificationRegistrationService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authStateChanges;
  late final NotificationRegistrationService _notificationRegistrationService;

  @override
  void initState() {
    super.initState();
    // A new auth stream on a rebuild briefly removes the navigation shell,
    // losing the current tab and its subscriptions during back navigation.
    _authStateChanges = (widget.authService ?? AuthService()).authStateChanges;
    _notificationRegistrationService =
        widget.notificationRegistrationService ??
        NotificationRegistrationService.instance;
  }

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
      stream: _authStateChanges,
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

        return KeyedSubtree(
          key: ValueKey(user.uid),
          child: widget.authenticatedBuilder(context),
        );
      },
    );
  }
}
