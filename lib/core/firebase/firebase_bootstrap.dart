import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import '../notifications/notification_bootstrap.dart';
import 'firebase_app_check_bootstrap.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await FirebaseAppCheckBootstrap.initialize();

    await NotificationBootstrap.initialize();
  }
}
