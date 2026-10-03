import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationMessageHandler {
  NotificationMessageHandler._internal();

  static final NotificationMessageHandler instance =
      NotificationMessageHandler._internal();

  factory NotificationMessageHandler() => instance;

  static const String _channelId = 'yening_ecos_alerts';
  static const String _channelName = 'Yening Ecos Alerts';
  static const String _channelDescription =
      'Notifications for Yening Ecos device alerts and events.';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;

  FutureOr<void> Function(Map<String, String> data)? _notificationTapHandler;

  Map<String, String>? _pendingInitialNotification;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    await _initializeLocalNotifications();
    await _createAndroidNotificationChannel();

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM foreground listener failed: $error');

        debugPrintStack(stackTrace: stackTrace);
      },
    );

    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationOpened,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM notification-open listener failed: $error');

        debugPrintStack(stackTrace: stackTrace);
      },
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      final data = _normalizeData(initialMessage.data);

      if (data.isNotEmpty) {
        _pendingInitialNotification = data;

        _dispatchNotificationTap(data);
      }
    }

    debugPrint('Notification message handler initialized.');
  }

  void setNotificationTapHandler(
    FutureOr<void> Function(Map<String, String> data) handler,
  ) {
    _notificationTapHandler = handler;

    final pendingNotification = _pendingInitialNotification;

    if (pendingNotification != null) {
      _pendingInitialNotification = null;

      _dispatchNotificationTap(pendingNotification);
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('ic_launcher');

    final settings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
    );
  }

  Future<void> _createAndroidNotificationChannel() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) {
      return;
    }

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await androidPlugin.createNotificationChannel(channel);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('FCM foreground message received: ${message.messageId}');

    debugPrint('FCM foreground data: ${message.data}');

    final notification = message.notification;

    if (notification == null) {
      debugPrint(
        'FCM message has no notification payload. '
        'No local notification will be shown.',
      );

      return;
    }

    final title = notification.title ?? 'Yening Ecos';
    final body = notification.body ?? '';

    final payload = jsonEncode(_normalizeData(message.data));

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: 'ic_launcher',
        autoCancel: true,
      ),
    );

    await _localNotifications.show(
      id: _notificationId(message),
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  Future<void> _handleNotificationOpened(RemoteMessage message) async {
    debugPrint('FCM notification opened: ${message.messageId}');

    final data = _normalizeData(message.data);

    if (data.isEmpty) {
      return;
    }

    _dispatchNotificationTap(data);
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;

    if (payload == null || payload.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(payload);

      if (decoded is! Map) {
        return;
      }

      final data = <String, String>{};

      decoded.forEach((key, value) {
        if (key == null || value == null) {
          return;
        }

        data[key.toString()] = value.toString();
      });

      if (data.isNotEmpty) {
        _dispatchNotificationTap(data);
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to parse local notification payload: $error');

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _dispatchNotificationTap(Map<String, String> data) {
    final handler = _notificationTapHandler;

    if (handler == null) {
      _pendingInitialNotification = data;

      debugPrint(
        'Notification tap received before the app registered '
        'a notification tap handler.',
      );

      return;
    }

    try {
      final result = handler(data);

      if (result is Future) {
        unawaited(result);
      }
    } catch (error, stackTrace) {
      debugPrint('Notification tap handler failed: $error');

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Map<String, String> _normalizeData(Map<String, dynamic> data) {
    final normalized = <String, String>{};

    data.forEach((key, value) {
      if (value == null) {
        return;
      }

      normalized[key] = value.toString();
    });

    return normalized;
  }

  int _notificationId(RemoteMessage message) {
    final messageId = message.messageId;

    if (messageId != null && messageId.isNotEmpty) {
      return messageId.hashCode & 0x7fffffff;
    }

    return DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
  }

  Future<void> dispose() async {
    await _foregroundMessageSubscription?.cancel();
    await _openedAppSubscription?.cancel();

    _foregroundMessageSubscription = null;
    _openedAppSubscription = null;
    _notificationTapHandler = null;
    _pendingInitialNotification = null;
    _initialized = false;
  }
}
