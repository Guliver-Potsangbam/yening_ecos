import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yening_ecos/core/preferences/temperature_unit_preference.dart';
import 'package:yening_ecos/core/ui/local_time_format.dart';
import 'package:yening_ecos/features/devices/device_details_page.dart';
import 'package:yening_ecos/features/devices/models/device_details.dart';
import 'package:yening_ecos/features/devices/models/device_telemetry.dart';
import 'package:yening_ecos/features/devices/models/user_device.dart';
import 'package:yening_ecos/features/devices/services/device_details_service.dart';
import 'package:yening_ecos/features/devices/widgets/device_metadata_panel.dart';

const _device = UserDevice(
  deviceId: 'device-1',
  deviceName: 'Living room',
  serialNumber: 'SN-001',
  deviceTypeId: 'model-1',
);

DeviceDetails _details() => DeviceDetails.fromMaps(
  documentId: 'device-1',
  deviceData: {
    'deviceName': 'Living room',
    'serialNumber': 'SN-001',
    'deviceTypeId': 'model-1',
    'status': 'claimed',
    'provisioningStatus': 'provisioned',
    'active': true,
    'claimedByUid': 'private-owner-uid',
    'wifiPassword': 'private-password',
    'firmware': {
      'version': '1.0.0',
      'channel': 'stable',
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 7, 8, 30)),
    },
    'service': {'serviceCount': 0},
  },
  typeData: {
    'description': 'Environmental monitoring for your space.',
    'deviceTypeName': 'EnviroSense Basic',
    'version': '1.0.0',
    'hardware': {
      'controller': 'ESP32',
      'board': 'ESP32 Dev Module',
      'connectivity': ['wifi'],
    },
    'telemetry': {
      'temperature': {
        'name': 'Temperature',
        'source': {'sensorType': 'dht22'},
        'supportedUnits': ['celsius', 'fahrenheit'],
      },
    },
    'controls': {
      'relay1': {
        'name': 'Relay 1',
        'type': 'relay',
        'supportedModes': ['manual', 'automation'],
      },
    },
  },
);

void main() {
  late TemperatureUnitPreference units;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    units = TemperatureUnitPreference();
    await units.load();
  });

  tearDown(() => units.dispose());

  testWidgets('metadata loading and errors leave live readings visible', (
    tester,
  ) async {
    final metadata = StreamController<DeviceDetailsState>.broadcast();
    final readings = StreamController<DeviceTelemetry>.broadcast();
    addTearDown(metadata.close);
    addTearDown(readings.close);
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceDetailsPage(
          device: _device,
          metadataSource: (_) => metadata.stream,
          telemetrySource: (_) => readings.stream,
          unitPreference: units,
        ),
      ),
    );
    readings.add(
      const DeviceTelemetry(
        temperatureCelsius: 24,
        humidity: 60,
        lightPercent: 75,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('24.0°C'), findsOneWidget);
    metadata.addError(StateError('private-token-diagnostic'));
    await tester.pumpAndSettle();
    expect(find.text('24.0°C'), findsOneWidget);
    expect(find.textContaining('private-token'), findsNothing);
    readings.add(
      const DeviceTelemetry(
        temperatureCelsius: 25,
        humidity: 61,
        lightPercent: 76,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('25.0°C'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(metadata.hasListener, isFalse);
    expect(readings.hasListener, isFalse);
  });

  testWidgets(
    'switching the device clears previous metadata before the next document arrives',
    (tester) async {
      final first = StreamController<DeviceDetailsState>.broadcast();
      final second = StreamController<DeviceDetailsState>.broadcast();
      addTearDown(first.close);
      addTearDown(second.close);
      final key = GlobalKey();
      Widget page(UserDevice device) => MaterialApp(
        home: DeviceDetailsPage(
          key: key,
          device: device,
          metadataSource: (id) =>
              id == 'device-1' ? first.stream : second.stream,
          telemetrySource: (_) => Stream.value(const DeviceTelemetry()),
          unitPreference: units,
        ),
      );
      await tester.pumpWidget(page(_device));
      first.add(DeviceDetailsState.ready(_details()));
      await tester.pumpAndSettle();
      expect(find.text('Living room'), findsOneWidget);
      await tester.pumpWidget(
        page(
          const UserDevice(
            deviceId: 'device-2',
            deviceName: 'Bedroom',
            serialNumber: '',
            deviceTypeId: 'model-2',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Bedroom'), findsOneWidget);
      expect(find.text('Living room'), findsNothing);
      final panel = tester.widget<DeviceMetadataPanel>(
        find.byType(DeviceMetadataPanel),
      );
      expect(panel.state.isLoading, isTrue);
      expect(panel.state.details, isNull);
      expect(first.hasListener, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(second.hasListener, isFalse);
    },
  );

  testWidgets(
    'retry clears the old metadata error without restarting telemetry',
    (tester) async {
      final first = StreamController<DeviceDetailsState>.broadcast();
      final second = StreamController<DeviceDetailsState>.broadcast();
      var metadataWatches = 0;
      var readingSubscriptions = 0;
      var readingCancellations = 0;
      final readings = StreamController<DeviceTelemetry>.broadcast(
        onListen: () => ++readingSubscriptions,
        onCancel: () => ++readingCancellations,
      );
      addTearDown(first.close);
      addTearDown(second.close);
      addTearDown(readings.close);
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceDetailsPage(
            device: _device,
            metadataSource: (_) =>
                ++metadataWatches == 1 ? first.stream : second.stream,
            telemetrySource: (_) => readings.stream,
            unitPreference: units,
          ),
        ),
      );
      readings.add(const DeviceTelemetry(temperatureCelsius: 24));
      first.add(DeviceDetailsState.ready(_details()));
      await tester.pumpAndSettle();
      first.addError(StateError('old error'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Retry device information'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Retry device information'));
      await tester.pump();
      final panel = tester.widget<DeviceMetadataPanel>(
        find.byType(DeviceMetadataPanel),
      );
      expect(panel.state.isLoading, isTrue);
      expect(panel.state.message, isNull);
      expect(panel.state.details, isNull);
      expect(first.hasListener, isFalse);
      expect(second.hasListener, isTrue);
      expect(readingSubscriptions, 1);
      expect(readingCancellations, 0);
      second.add(DeviceDetailsState.ready(_details()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'shows organized metadata and local AM/PM dates without private fields',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DeviceMetadataPanel(
                state: DeviceDetailsState.ready(_details()),
                onRetry: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Environmental monitoring for your space.'),
        findsOneWidget,
      );
      expect(find.text('Claimed'), findsOneWidget);
      expect(find.text('Provisioned'), findsOneWidget);
      expect(
        find.text(formatLocalDateTime12(DateTime.utc(2026, 10, 7, 8, 30))),
        findsOneWidget,
      );
      expect(find.textContaining('private-'), findsNothing);
      await tester.tap(find.text('Hardware & connectivity'));
      await tester.pumpAndSettle();
      expect(find.text('ESP32 Dev Module'), findsOneWidget);
      expect(find.text('Wi-Fi'), findsOneWidget);
      await tester.ensureVisible(find.text('Temperature capability'));
      await tester.tap(find.text('Temperature capability'));
      await tester.pumpAndSettle();
      expect(find.text('DHT22'), findsOneWidget);
      expect(find.text('Celsius (°C) · Fahrenheit (°F)'), findsOneWidget);
      expect(find.text('Relay 1 capability'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('metadata adapts to a narrow screen with double-size text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: DeviceMetadataPanel(
                state: DeviceDetailsState.ready(_details()),
                onRetry: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Device reference'));
    await tester.tap(find.text('Device reference'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Copy device id'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
