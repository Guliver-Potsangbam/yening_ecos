import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/device_telemetry.dart';

typedef DeviceTelemetrySource = Stream<DeviceTelemetry> Function(
  String deviceId,
);

class DeviceTelemetryService {
  DeviceTelemetryService({this.database});

  // Same regional database used by the supplied ESP32 firmware.
  static const databaseUrl =
      'https://yening-ecos-development-default-rtdb.asia-southeast1.firebasedatabase.app';
  final FirebaseDatabase? database;

  Stream<DeviceTelemetry> watchDevice(String deviceId) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(deviceId)) {
      throw ArgumentError.value(
        deviceId,
        'deviceId',
        'Invalid device identity',
      );
    }
    final liveDatabase =
        database ??
        FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: databaseUrl,
        );
    return Stream<DeviceTelemetry>.multi((controller) {
      DeviceTelemetry? latest;
      bool? connected;
      var cancelled = false;
      void emit() {
        final reading = latest;
        if (cancelled || reading == null) return;
        controller.add(
          DeviceTelemetry(
            temperatureCelsius: reading.temperatureCelsius,
            humidity: reading.humidity,
            lastSeen: reading.lastSeen,
            isOnline: reading.isOnline,
            isCloudConnected: connected,
          ),
        );
      }

      final connection = liveDatabase.ref('.info/connected').onValue.listen((
        event,
      ) {
        connected = event.snapshot.value == true;
        emit();
      }, onError: controller.addError);
      final readings = liveDatabase.ref('deviceLive/$deviceId').onValue.listen((
        event,
      ) {
        latest = DeviceTelemetry.fromValue(event.snapshot.value);
        emit();
      }, onError: controller.addError);
      controller.onCancel = () async {
        cancelled = true;
        await Future.wait([connection.cancel(), readings.cancel()]);
      };
    });
  }
}
