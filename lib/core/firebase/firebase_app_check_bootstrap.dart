import 'package:firebase_app_check/firebase_app_check.dart';

class FirebaseAppCheckBootstrap {
  FirebaseAppCheckBootstrap._();

  static Future<void> initialize() async {
    await FirebaseAppCheck.instance.activate(
      // for development
      providerAndroid: const AndroidDebugProvider(),

      // later for production
      // providerAndroid: const AndroidPlayIntegrityProvider(),
    );
  }
}
