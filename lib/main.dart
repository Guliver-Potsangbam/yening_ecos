import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app/app.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/notifications/notification_message_handler.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await FirebaseBootstrap.initialize();

  runApp(const MyApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    FlutterNativeSplash.remove();

    unawaited(_initializeNotificationMessageHandler());
  });
}

Future<void> _initializeNotificationMessageHandler() async {
  try {
    await NotificationMessageHandler.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('Notification message handler initialization failed: $error');

    debugPrintStack(stackTrace: stackTrace);
  }
}
