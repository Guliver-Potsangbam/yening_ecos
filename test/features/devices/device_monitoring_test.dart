import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yening_ecos/core/preferences/temperature_unit_preference.dart';
import 'package:yening_ecos/features/devices/device_details_page.dart';
import 'package:yening_ecos/features/devices/devices_page.dart';
import 'package:yening_ecos/features/devices/models/device_telemetry.dart';
import 'package:yening_ecos/features/devices/models/user_device.dart';
import 'package:yening_ecos/features/devices/services/user_devices_service.dart';
import 'package:yening_ecos/features/devices/widgets/device_telemetry_panel.dart';
import 'package:yening_ecos/features/devices/widgets/telemetry_gauge.dart';
import 'package:yening_ecos/features/home/home_page.dart';

void main() {
  const device = UserDevice(
    deviceId: 'YEC-DEV-000001',
    deviceName: 'EnviroSense Basic',
    serialNumber: 'SN-001',
    deviceTypeId: 'envirosense_basic_v1',
  );
  late TemperatureUnitPreference units;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    units = TemperatureUnitPreference();
    await units.load();
  });
  tearDown(() => units.dispose());

  testWidgets(
    'Home shows live gauges, updates values and converts Celsius to Fahrenheit',
    (tester) async {
      final devices = StreamController<UserDevicesState>();
      final readings = StreamController<DeviceTelemetry>.broadcast();
      addTearDown(() {
        unawaited(readings.close());
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomePage(
              devicesStream: devices.stream,
              telemetrySource: (_) => readings.stream,
              unitPreference: units,
            ),
          ),
        ),
      );
      devices.add(const UserDevicesState.loaded([device]));
      await tester.pump();
      readings.add(
        DeviceTelemetry(
          temperatureCelsius: 25,
          humidity: 61.5,
          lastSeen: DateTime.now(),
          isOnline: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('25.0°C'), findsOneWidget);
      expect(find.text('61.5%'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      await tester.tap(find.text('°F'));
      await tester.pumpAndSettle();
      expect(find.text('77.0°F'), findsOneWidget);
      expect(
        find.byType(DeviceDetailsPage),
        findsNothing,
        reason: 'unit toggles do not activate the enclosing device card',
      );
      final temperature = tester.widget<TelemetryGauge>(
        find.byType(TelemetryGauge).first,
      );
      expect(temperature.minimum, -40);
      expect(temperature.maximum, 176);
      readings.add(
        DeviceTelemetry(
          temperatureCelsius: 30,
          humidity: 50,
          lastSeen: DateTime.now(),
          isOnline: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('86.0°F'), findsOneWidget);
      expect(find.text('50.0%'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      unawaited(devices.close());
      expect(readings.hasListener, isFalse);
    },
  );

  testWidgets(
    'tapping a Devices card opens details with identity and live telemetry',
    (tester) async {
      final devices = StreamController<UserDevicesState>();
      final readings = StreamController<DeviceTelemetry>.broadcast();
      addTearDown(() {
        unawaited(readings.close());
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DevicesPage(
              devicesStream: devices.stream,
              telemetrySource: (_) => readings.stream,
              unitPreference: units,
            ),
          ),
        ),
      );
      devices.add(const UserDevicesState.loaded([device]));
      await tester.pump();
      await tester.tap(find.text('EnviroSense Basic'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(DeviceDetailsPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DeviceDetailsPage),
          matching: find.text('Serial: SN-001'),
        ),
        findsOneWidget,
      );
      readings.add(
        DeviceTelemetry(
          temperatureCelsius: 0,
          humidity: 0,
          lastSeen: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0.0°C'), findsOneWidget);
      expect(find.text('0.0%'), findsOneWidget);
      await tester.tap(find.text('°F'));
      await tester.pumpAndSettle();
      expect(find.text('32.0°F'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(readings.hasListener, isFalse);
      unawaited(devices.close());
      expect(readings.hasListener, isFalse);
    },
  );

  testWidgets(
    'missing readings and stale readings are labeled without fabricating zeroes',
    (tester) async {
      final readings = StreamController<DeviceTelemetry>.broadcast();
      addTearDown(() {
        unawaited(readings.close());
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceTelemetryPanel(
              deviceId: device.deviceId,
              telemetrySource: (_) => readings.stream,
              unitPreference: units,
            ),
          ),
        ),
      );
      readings.add(const DeviceTelemetry());
      await tester.pumpAndSettle();
      expect(find.text('Waiting for readings'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('0.0°C'), findsNothing);
      readings.add(
        DeviceTelemetry(
          temperatureCelsius: 24,
          humidity: 40,
          lastSeen: DateTime.now().subtract(const Duration(minutes: 2)),
          isOnline: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No recent updates'), findsOneWidget);
      expect(find.text('24.0°C'), findsOneWidget);
      readings.addError(
        FirebaseException(
          plugin: 'firebase_database',
          code: 'permission-denied',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Your account cannot access this device’s readings.'),
        findsOneWidget,
      );
      expect(find.text('Retry readings'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(readings.hasListener, isFalse);
    },
  );

  testWidgets('gauges fit a narrow screen and large text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: DeviceDetailsPage(
              device: device,
              telemetrySource: (_) => Stream.value(
                const DeviceTelemetry(temperatureCelsius: -40, humidity: 100),
              ),
              unitPreference: units,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('-40.0°C'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Home and device details share the selected temperature unit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(
            devicesStream: Stream.value(
              const UserDevicesState.loaded([device]),
            ),
            telemetrySource: (_) => Stream.value(
              DeviceTelemetry(
                temperatureCelsius: 25,
                humidity: 50,
                lastSeen: DateTime.now(),
              ),
            ),
            unitPreference: units,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('25.0°C'), findsOneWidget);
    await tester.tap(find.text('EnviroSense Basic'));
    await tester.pumpAndSettle();
    expect(find.byType(DeviceDetailsPage), findsOneWidget);
    await tester.tap(find.text('°F'));
    await tester.pumpAndSettle();
    expect(find.text('77.0°F'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DeviceDetailsPage), findsNothing);
    expect(find.text('77.0°F'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
