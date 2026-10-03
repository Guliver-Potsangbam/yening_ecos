import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_messaging_service.dart';
import 'notification_token_service.dart';

class NotificationRegistrationService {
  NotificationRegistrationService._internal();

  static final NotificationRegistrationService instance =
      NotificationRegistrationService._internal();

  factory NotificationRegistrationService() => instance;

  static const String _installationIdKey = 'notification_installation_id';

  final FirebaseMessagingService _messagingService = FirebaseMessagingService();

  final NotificationTokenService _tokenService = NotificationTokenService();

  StreamSubscription<String>? _tokenRefreshSubscription;

  String? _installationId;
  String? _registeredUid;

  Future<void> initializeForUser({required String uid}) async {
    final normalizedUid = uid.trim();

    if (normalizedUid.isEmpty) {
      return;
    }

    // Already actively registered for this exact authenticated user.
    if (_registeredUid == normalizedUid && _tokenRefreshSubscription != null) {
      debugPrint('FCM registration already active for user $normalizedUid.');
      return;
    }

    // If another user was registered without going through our
    // normal logout flow, clean up that registration first.
    if (_registeredUid != null && _registeredUid != normalizedUid) {
      await unregisterForUser(uid: _registeredUid!);
    } else {
      await dispose();
    }

    _registeredUid = normalizedUid;

    try {
      /*
       * This can safely be called every time the user signs in.
       *
       * If permission has already been granted, Android does not
       * show the permission dialog again. The existing permission
       * state is returned and we continue to get the FCM token.
       */
      final token = await _messagingService.initializeForDevice();

      if (token == null) {
        debugPrint(
          'FCM registration skipped because notification permission '
          'was not granted.',
        );
        return;
      }

      final installationId = await _getOrCreateInstallationId();

      _installationId = installationId;

      await _tokenService.saveToken(
        uid: normalizedUid,
        installationId: installationId,
        token: token,
      );

      debugPrint('FCM token registered for user $normalizedUid.');

      await _tokenRefreshSubscription?.cancel();

      _tokenRefreshSubscription = _messagingService.onTokenRefresh.listen(
        (newToken) {
          unawaited(
            _handleTokenRefresh(
              uid: normalizedUid,
              installationId: installationId,
              newToken: newToken,
            ),
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('FCM token refresh listener failed: $error');

          debugPrintStack(stackTrace: stackTrace);
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Notification registration failed: $error');

      debugPrintStack(stackTrace: stackTrace);

      // Allow the next authenticated session attempt to retry.
      _registeredUid = null;
    }
  }

  Future<void> unregisterForUser({required String uid}) async {
    final normalizedUid = uid.trim();

    if (normalizedUid.isEmpty) {
      return;
    }

    try {
      final installationId =
          _installationId ?? await _getStoredInstallationId();

      if (installationId == null) {
        debugPrint(
          'No notification installation ID found for user '
          '$normalizedUid.',
        );
        return;
      }

      await _tokenService.removeToken(
        uid: normalizedUid,
        installationId: installationId,
      );

      debugPrint('FCM registration removed for user $normalizedUid.');
    } catch (error, stackTrace) {
      debugPrint('Failed to remove FCM registration: $error');

      debugPrintStack(stackTrace: stackTrace);
    } finally {
      await dispose();
    }
  }

  Future<void> _handleTokenRefresh({
    required String uid,
    required String installationId,
    required String newToken,
  }) async {
    // Ignore a late token-refresh event from a session that has
    // already been signed out or replaced.
    if (_registeredUid != uid) {
      debugPrint('Ignoring stale FCM token refresh for user $uid.');
      return;
    }

    try {
      await _tokenService.saveToken(
        uid: uid,
        installationId: installationId,
        token: newToken,
      );

      debugPrint('FCM token updated for user $uid.');
    } catch (error, stackTrace) {
      debugPrint('Failed to persist refreshed FCM token: $error');

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<String> _getOrCreateInstallationId() async {
    final preferences = await SharedPreferences.getInstance();

    final existingId = preferences.getString(_installationIdKey);

    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }

    final random = Random.secure();

    final installationId =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '_${random.nextInt(1 << 32).toRadixString(36)}';

    await preferences.setString(_installationIdKey, installationId);

    return installationId;
  }

  Future<String?> _getStoredInstallationId() async {
    final preferences = await SharedPreferences.getInstance();

    final installationId = preferences.getString(_installationIdKey);

    if (installationId == null || installationId.isEmpty) {
      return null;
    }

    return installationId;
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();

    _tokenRefreshSubscription = null;
    _registeredUid = null;
    _installationId = null;
  }
}
