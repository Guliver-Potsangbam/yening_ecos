import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

class NotificationBootstrap {
  NotificationBootstrap._();

  static Future<void> initialize() async {
    // This is the only notification setup that must happen
    // before runApp().
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('FCM background message received: ${message.messageId}');

  debugPrint('FCM background message data: ${message.data}');
}
