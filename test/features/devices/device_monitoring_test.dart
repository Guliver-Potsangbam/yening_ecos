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
    'Home switches one telemetry subscription and falls back when its device is removed',
    (tester) async {
      const second = UserDevice(
        deviceId: 'device-2',
        deviceName: 'Kitchen',
        serialNumber: 'SN-002',
        deviceTypeId: 'envirosense_basic_v1',
      );
      final devices = StreamController<UserDevicesState>();
      final firstReadings = StreamController<DeviceTelemetry>.broadcast();
      final secondReadings = StreamController<DeviceTelemetry>.broadcast();
      addTearDown(() async {
        await devices.close();
        await firstReadings.close();
        await secondReadings.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomePage(
              devicesStream: devices.stream,
              telemetrySource: (id) => id == device.deviceId
                  ? firstReadings.stream
                  : secondReadings.stream,
              unitPreference: units,
            ),
          ),
        ),
      );
      devices.add(const UserDevicesState.loaded([device]));
      await tester.pump();
      firstReadings.add(
        const DeviceTelemetry(
          temperatureCelsius: 25,
          humidity: 60,
          lightPercent: 40,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Switch device'), findsNothing);
      expect(find.text('Add Device'), findsNothing);
      devices.add(const UserDevicesState.loaded([device, second]));
      await tester.pump();
      await tester.pump();
      expect(firstReadings.hasListener, isTrue);
      expect(secondReadings.hasListener, isFalse);
      await tester.tap(find.byTooltip('Switch device'));
      await tester.pumpAndSettle();
      expect(find.text('Select a device'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('select-device-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      secondReadings.add(
        const DeviceTelemetry(
          temperatureCelsius: 30,
          humidity: 45,
          lightPercent: 80,
        ),
      );
      await tester.pumpAndSettle();
      expect(firstReadings.hasListener, isFalse);
      expect(secondReadings.hasListener, isTrue);
      expect(find.text('EnviroSense Basic'), findsNothing);
      expect(find.text('Kitchen'), findsOneWidget);
      expect(find.text('30.0°C'), findsOneWidget);
      expect(find.text('80.0%'), findsOneWidget);
      // Registry reordering preserves the selection, without restarting telemetry.
      devices.add(const UserDevicesState.loaded([second, device]));
      await tester.pump();
      await tester.pump();
      expect(find.text('Kitchen'), findsOneWidget);
      // Removing ownership clears the previous readings and selects the survivor.
      devices.add(const UserDevicesState.loaded([device]));
      await tester.pump();
      await tester.pump();
      expect(secondReadings.hasListener, isFalse);
      expect(firstReadings.hasListener, isTrue);
      expect(find.text('30.0°C'), findsNothing);
      expect(find.byTooltip('Switch device'), findsNothing);
      firstReadings.add(
        const DeviceTelemetry(
          temperatureCelsius: 26,
          humidity: 65,
          lightPercent: 42,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('26.0°C'), findsOneWidget);
      devices.add(const UserDevicesState.loading());
      await tester.pump();
      await tester.pump();
      expect(firstReadings.hasListener, isFalse);
      expect(find.text('26.0°C'), findsNothing);
      devices.add(const UserDevicesState.loaded([]));
      await tester.pumpAndSettle();
      expect(find.text('Add Device'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
          lightPercent: 43.2,
          lastSeen: DateTime.now(),
          isOnline: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('25.0°C'), findsOneWidget);
      expect(find.text('61.5%'), findsOneWidget);
      expect(find.text('43.2%'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Bright'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      await tester.tap(find.text('°F'));
      await tester.pumpAndSettle();
      expect(find.text('77.0°F'), findsOneWidget);
      expect(find.text('43.2%'), findsOneWidget);
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
          lightPercent: 82.5,
          lastSeen: DateTime.now(),
          isOnline: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('86.0°F'), findsOneWidget);
      expect(find.text('50.0%'), findsOneWidget);
      expect(find.text('82.5%'), findsOneWidget);
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
          lightPercent: 0,
          lastSeen: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0.0°C'), findsOneWidget);
      expect(find.text('0.0%'), findsNWidgets(2));
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
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
      expect(find.text('—'), findsNWidgets(3));
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

  testWidgets(
    'light label follows each five-second reading and clears when missing',
    (tester) async {
      final readings = StreamController<DeviceTelemetry>.broadcast();
      addTearDown(() => readings.close());
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
      final semantics = tester.ensureSemantics();
      for (final entry in <double, String>{
        0: 'Dark',
        5: 'Dark',
        5.1: 'Low light',
        20: 'Low light',
        20.1: 'Bright',
        100: 'Bright',
      }.entries) {
        readings.add(DeviceTelemetry(lightPercent: entry.key));
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
        expect(find.text(entry.value), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            'Light: ${entry.key.toStringAsFixed(1)} %, ${entry.value}',
          ),
          findsOneWidget,
        );
        for (final other in ['Dark', 'Low light', 'Bright']) {
          if (other != entry.value) expect(find.text(other), findsNothing);
        }
      }
      readings.add(const DeviceTelemetry());
      await tester.pumpAndSettle();
      expect(find.text('Dark'), findsNothing);
      expect(find.text('Low light'), findsNothing);
      expect(find.text('Bright'), findsNothing);
      expect(find.text('—'), findsNWidgets(3));
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('identical values still display each new server update time', (
    tester,
  ) async {
    final readings = StreamController<DeviceTelemetry>.broadcast();
    addTearDown(() => readings.close());
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
    final startedAt = DateTime(2026, 10, 7, 14, 30);
    for (var tick = 0; tick < 3; tick++) {
      readings.add(
        DeviceTelemetry(
          temperatureCelsius: 28.5,
          humidity: 62.3,
          lightPercent: 0,
          lastSeen: startedAt.add(Duration(seconds: tick * 5)),
          isOnline: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('28.5°C'), findsOneWidget);
      expect(find.text('62.3%'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('telemetry-updated-time')))
            .data,
        'Last update: 14:30:${(tick * 5).toString().padLeft(2, '0')}',
      );
      await tester.pump(const Duration(seconds: 5));
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('light continues updating when DHT22 readings are unavailable', (
    tester,
  ) async {
    final readings = StreamController<DeviceTelemetry>.broadcast();
    addTearDown(() => readings.close());
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
    readings.add(
      DeviceTelemetry.fromValue({
        'telemetry': {'temperature': 24, 'humidity': 60, 'light': 40},
        'connectivity': {
          'isOnline': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        },
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('24.0°C'), findsOneWidget);
    readings.add(
      DeviceTelemetry.fromValue({
        'telemetry': {'light': 75},
        'connectivity': {
          'isOnline': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        },
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('75.0%'), findsOneWidget);
    expect(find.text('24.0°C'), findsNothing);
    expect(find.text('—'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
    expect(readings.hasListener, isFalse);
  });

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
                const DeviceTelemetry(
                  temperatureCelsius: -40,
                  humidity: 100,
                  lightPercent: 72.5,
                ),
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
    expect(find.text('72.5%'), findsOneWidget);
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
