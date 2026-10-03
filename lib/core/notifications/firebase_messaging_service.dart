import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FirebaseMessagingService {
  FirebaseMessagingService({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  Future<NotificationSettings> requestPermission() {
    return _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  Future<String?> getToken() {
    return _messaging.getToken();
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Future<NotificationSettings> get notificationSettings {
    return _messaging.getNotificationSettings();
  }

  Future<String?> initializeForDevice() async {
    final settings = await requestPermission();

    debugPrint(
      'FCM notification permission: '
      '${settings.authorizationStatus}',
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('FCM notification permission was denied.');
      return null;
    }

    final token = await getToken();

    debugPrint('FCM registration token: $token');

    return token;
  }
}
