import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yening_ecos/core/preferences/temperature_unit_preference.dart';
import 'package:yening_ecos/core/ui/app_theme.dart';
import 'package:yening_ecos/features/devices/device_details_page.dart';
import 'package:yening_ecos/features/devices/models/device_details.dart';
import 'package:yening_ecos/features/devices/models/device_telemetry.dart';
import 'package:yening_ecos/features/devices/models/user_device.dart';
import 'package:yening_ecos/features/devices/services/device_details_service.dart';
import 'package:yening_ecos/features/devices/services/user_devices_service.dart';
import 'package:yening_ecos/features/devices/widgets/device_telemetry_panel.dart';
import 'package:yening_ecos/features/devices/widgets/telemetry_gauge.dart';
import 'package:yening_ecos/features/devices/widgets/user_device_card.dart';
import 'package:yening_ecos/features/devices/widgets/temperature_unit_selector.dart';
import 'package:yening_ecos/features/home/home_page.dart';

const _previewDirectory = String.fromEnvironment('TELEMETRY_PREVIEW_DIR');
const _previewFont = String.fromEnvironment('TELEMETRY_PREVIEW_FONT');
const _device = UserDevice(
  deviceId: 'YEC-DEV-000001',
  deviceName: 'EnviroSense Basic',
  serialNumber: 'YEC-ENV-26-000001',
  deviceTypeId: 'envirosense_basic_v1',
);

DeviceDetails _previewMetadata() => DeviceDetails.fromMaps(
  documentId: _device.deviceId,
  deviceData: {
    'deviceName': _device.deviceName,
    'serialNumber': _device.serialNumber,
    'deviceTypeId': _device.deviceTypeId,
    'status': 'claimed',
    'provisioningStatus': 'provisioned',
    'active': true,
    'schemaVersion': 1,
    'firmware': {'version': '1.0.0', 'channel': 'stable'},
    'lifecycle': {'manufacturedAt': DateTime(2026, 9, 1, 10)},
    'claimedAt': DateTime(2026, 10, 7, 14, 30),
    'service': {'serviceCount': 0},
  },
  typeData: {
    'deviceTypeName': 'EnviroSense Basic',
    'description': 'Environmental monitoring for your space.',
    'version': '1.0.0',
    'hardware': {
      'controller': 'ESP32',
      'board': 'ESP32 Dev Module',
      'connectivity': ['wifi'],
    },
    'telemetry': {
      for (final metric in ['temperature', 'humidity', 'light'])
        metric: {
          'name': metric[0].toUpperCase() + metric.substring(1),
          'source': {
            'sensorType': metric == 'light' ? 'ldr' : 'dht22',
            'interface': metric == 'light' ? 'analog' : 'digital',
          },
          'canonicalUnit': metric == 'temperature' ? 'celsius' : 'percent',
          'supportedUnits': metric == 'temperature'
              ? ['celsius', 'fahrenheit']
              : ['percent'],
          'readOnly': true,
        },
    },
  },
);

void main() {
  late TemperatureUnitPreference units;
  setUpAll(() async {
    if (_previewFont.isNotEmpty) {
      final bytes = await File(_previewFont).readAsBytes();
      await (FontLoader(
        'MeterPreview',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    units = TemperatureUnitPreference();
    await units.load();
  });
  tearDown(() => units.dispose());

  Widget panel(DeviceTelemetry reading) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: DeviceTelemetryPanel(
          deviceId: _device.deviceId,
          telemetrySource: (_) => Stream.value(reading),
          unitPreference: units,
        ),
      ),
    ),
  );

  testWidgets(
    'mobile meters have equal dimensions and units belong only to temperature',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        panel(
          const DeviceTelemetry(
            temperatureCelsius: 28.5,
            humidity: 62.3,
            lightPercent: 78.4,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final temperature = find.byKey(const ValueKey('temperature-meter'));
      final humidity = find.byKey(const ValueKey('humidity-meter'));
      final light = find.byKey(const ValueKey('light-meter'));
      expect(
        find.descendant(
          of: temperature,
          matching: find.byType(TemperatureUnitSelector),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: humidity,
          matching: find.byType(TemperatureUnitSelector),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: light,
          matching: find.byType(TemperatureUnitSelector),
        ),
        findsNothing,
      );
      expect(find.text('Relative humidity'), findsOneWidget);
      expect(find.text('Relative brightness'), findsOneWidget);
      expect(find.text('62.3% RH'), findsOneWidget);
      expect(find.text('78.4%'), findsOneWidget);
      expect(
        tester.widget<TelemetryGauge>(humidity).semanticUnit,
        'percent relative humidity',
      );
      expect(
        tester.widget<TelemetryGauge>(light).semanticUnit,
        'percent relative brightness',
      );
      for (final entry in [
        ('Temperature', temperature),
        ('Humidity', humidity),
      ]) {
        await tester.tap(
          find.descendant(
            of: entry.$2,
            matching: find.byIcon(Icons.info_outline_rounded),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('About ${entry.$1}'), findsOneWidget);
        await tester.tap(find.byTooltip('Close information'));
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.descendant(
          of: light,
          matching: find.byIcon(Icons.info_outline_rounded),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('About Light'), findsOneWidget);
      expect(find.textContaining('not a lux measurement'), findsOneWidget);
      expect(find.textContaining('dark (0%)'), findsOneWidget);
      expect(
        find.textContaining('differences use percentage points'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close information'));
      await tester.pumpAndSettle();
      expect(tester.getSize(temperature), tester.getSize(humidity));
      expect(tester.getSize(temperature), tester.getSize(light));
      final value = tester.widget<Text>(find.text('28.5°C'));
      expect(value.style!.fontSize, 20);
      expect(value.style!.fontWeight, FontWeight.w700);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pump();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'temperature colors remain consistent after unit conversion and change across bands',
    (tester) async {
      for (final celsius in [10.0, 28.5, 40.0]) {
        await tester.pumpWidget(
          panel(DeviceTelemetry(temperatureCelsius: celsius)),
        );
        await tester.pumpAndSettle();
        final before = tester.widget<TelemetryGauge>(
          find.byKey(const ValueKey('temperature-meter')),
        );
        final expected = celsius <= 20
            ? before.lowColor
            : celsius <= 35
            ? before.color
            : before.highColor;
        expect(before.readingColor, expected);
        await tester.tap(find.text('°F'));
        await tester.pumpAndSettle();
        final after = tester.widget<TelemetryGauge>(
          find.byKey(const ValueKey('temperature-meter')),
        );
        expect(after.value, celsius * 9 / 5 + 32);
        expect(after.lowThreshold, 68);
        expect(after.highThreshold, 95);
        expect(after.readingColor, before.readingColor);
        expect(
          find.text('${(celsius * 9 / 5 + 32).toStringAsFixed(1)}°F'),
          findsOneWidget,
        );
        await tester.tap(find.text('°C'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'light bands agree with the Dark, Low light, and Bright boundary labels',
    (tester) async {
      for (final light in [0.0, 23.0, 23.1, 45.0, 45.1, 100.0]) {
        await tester.pumpWidget(panel(DeviceTelemetry(lightPercent: light)));
        await tester.pumpAndSettle();
        final meter = tester.widget<TelemetryGauge>(
          find.byKey(const ValueKey('light-meter')),
        );
        final expected = light <= 23
            ? meter.lowColor
            : light <= 45
            ? meter.color
            : meter.highColor;
        expect(meter.readingColor, expected);
        expect(
          find.text(DeviceTelemetry(lightPercent: light).lightLabel!),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('missing and nonfinite readings have no invented numeric value', (
    tester,
  ) async {
    await tester.pumpWidget(
      panel(
        const DeviceTelemetry(
          temperatureCelsius: double.nan,
          humidity: double.infinity,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('—'), findsNWidgets(3));
    expect(find.text('NaN°C'), findsNothing);
    expect(find.text('Infinity%'), findsNothing);
    expect(find.text('No reading'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final scene in [
    (
      name: 'home-phone',
      size: const Size(390, 844),
      brightness: Brightness.light,
      scale: 1.0,
      details: false,
      offline: false,
    ),
    (
      name: 'home-dark',
      size: const Size(390, 844),
      brightness: Brightness.dark,
      scale: 1.0,
      details: false,
      offline: false,
    ),
    (
      name: 'home-tablet',
      size: const Size(1000, 640),
      brightness: Brightness.light,
      scale: 1.0,
      details: false,
      offline: false,
    ),
    (
      name: 'details-phone',
      size: const Size(390, 844),
      brightness: Brightness.light,
      scale: 1.0,
      details: true,
      offline: false,
    ),
    (
      name: 'details-large-text',
      size: const Size(320, 1000),
      brightness: Brightness.light,
      scale: 1.5,
      details: true,
      offline: false,
    ),
    (
      name: 'details-largest-text',
      size: const Size(320, 1200),
      brightness: Brightness.dark,
      scale: 2.0,
      details: true,
      offline: false,
    ),
    (
      name: 'home-offline-phone',
      size: const Size(390, 844),
      brightness: Brightness.light,
      scale: 1.0,
      details: false,
      offline: true,
    ),
    (
      name: 'home-offline-dark',
      size: const Size(390, 844),
      brightness: Brightness.dark,
      scale: 1.0,
      details: false,
      offline: true,
    ),
    (
      name: 'details-offline-phone',
      size: const Size(390, 844),
      brightness: Brightness.light,
      scale: 1.0,
      details: true,
      offline: true,
    ),
    (
      name: 'details-offline-large-text',
      size: const Size(320, 1200),
      brightness: Brightness.dark,
      scale: 2.0,
      details: true,
      offline: true,
    ),
  ]) {
    testWidgets(
      '${scene.name} renders real monitoring widgets without overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(scene.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final capturedAt = DateTime.now();
        final reading = DeviceTelemetry(
          temperatureCelsius: 28.5,
          humidity: 62.3,
          lightPercent: 78.4,
          temperatureUpdatedAt: capturedAt,
          humidityUpdatedAt: capturedAt.subtract(const Duration(seconds: 1)),
          lightUpdatedAt: capturedAt,
          lastSeen: capturedAt,
          isOnline: !scene.offline,
          isCloudConnected: true,
        );
        final boundaryKey = GlobalKey();
        final appTheme = scene.brightness == Brightness.dark
            ? AppTheme.dark()
            : AppTheme.light();
        final theme = _previewFont.isEmpty
            ? appTheme
            : appTheme.copyWith(
                textTheme: appTheme.textTheme.apply(fontFamily: 'MeterPreview'),
                primaryTextTheme: appTheme.primaryTextTheme.apply(
                  fontFamily: 'MeterPreview',
                ),
              );
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scene.scale)),
                child: child!,
              ),
              home: scene.details
                  ? DeviceDetailsPage(
                      device: _device,
                      metadataSource: (_) => Stream.value(
                        DeviceDetailsState.ready(_previewMetadata()),
                      ),
                      telemetrySource: (_) => Stream.value(reading),
                      unitPreference: units,
                    )
                  : Scaffold(
                      appBar: AppBar(title: const Text('Yening Ecos')),
                      body: HomePage(
                        devicesStream: Stream.value(
                          const UserDevicesState.loaded([
                            _device,
                            UserDevice(
                              deviceId: 'device-2',
                              deviceName: 'Kitchen',
                              serialNumber: '',
                              deviceTypeId: 'envirosense_basic_v1',
                            ),
                          ]),
                        ),
                        telemetrySource: (_) => Stream.value(reading),
                        unitPreference: units,
                      ),
                      bottomNavigationBar: NavigationBar(
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home_rounded),
                            label: 'Home',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.devices_other_outlined),
                            label: 'Devices',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.notifications_none_rounded),
                            label: 'Alerts',
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('28.5°C'), findsOneWidget);
        expect(find.text('62.3% RH'), findsOneWidget);
        expect(find.text('78.4%'), findsOneWidget);
        expect(find.byType(TemperatureUnitSelector), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(UserDeviceCard),
            matching: find.text(
              scene.offline ? 'Device offline' : 'Device online',
            ),
          ),
          findsOneWidget,
        );
        if (scene.offline) {
          expect(find.text('Updates paused'), findsOneWidget);
          expect(find.text('Offline'), findsNWidgets(3));
          expect(find.text('Last reading'), findsNWidgets(3));
          expect(
            find.byKey(const ValueKey('offline-readings-notice')),
            findsOneWidget,
          );
          for (final gauge in tester.widgetList<TelemetryGauge>(
            find.byType(TelemetryGauge),
          )) {
            expect(gauge.readingColor, const Color(0xFF757575));
            final controlScheme = Theme.of(
              tester.element(
                find.byKey(
                  ValueKey('edit-target-${gauge.label.toLowerCase()}'),
                ),
              ),
            ).colorScheme;
            expect(
              controlScheme.surfaceContainerLow,
              scene.brightness == Brightness.dark
                  ? const Color(0xFF252629)
                  : const Color(0xFFE8EAED),
            );
            expect(
              controlScheme.primary,
              scene.brightness == Brightness.dark
                  ? const Color(0xFFBFC3C7)
                  : const Color(0xFF656B70),
            );
          }
        }

        final heartbeatBottom = tester
            .getBottomLeft(find.byKey(const ValueKey('telemetry-updated-time')))
            .dy;
        for (final key in [
          'temperature-meter',
          'humidity-meter',
          'light-meter',
        ]) {
          expect(
            heartbeatBottom,
            lessThan(tester.getTopLeft(find.byKey(ValueKey(key))).dy),
            reason: 'connection time stays in the header above all readings',
          );
        }
        expect(tester.takeException(), isNull);
        final meterSizes = [
          'temperature-meter',
          'humidity-meter',
          'light-meter',
        ].map((key) => tester.getSize(find.byKey(ValueKey(key))));
        expect(meterSizes.toSet(), hasLength(1));
        if (scene.name != 'home-tablet') {
          final summaryWidth = tester
              .getSize(find.byType(UserDeviceCard))
              .width;
          for (final size in meterSizes) {
            expect(
              size.width,
              summaryWidth,
              reason: 'monitoring cards align with the device summary without an inset',
            );
          }
          if (scene.offline) {
            expect(
              tester
                  .getSize(
                    find.byKey(const ValueKey('offline-readings-notice')),
                  )
                  .width,
              summaryWidth,
            );
          }
        }

        if (scene.name == 'home-tablet') {
          final temperature = tester.getTopLeft(
            find.byKey(const ValueKey('temperature-meter')),
          );
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('humidity-meter'))).dy,
            temperature.dy,
          );
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('light-meter'))).dy,
            temperature.dy,
          );
        }
        if (_previewDirectory.isNotEmpty) {
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final directory = await Directory(_previewDirectory)
                  .create(recursive: true);
              await File('${directory.path}/${scene.name}.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }
        if (scene.name == 'details-phone') {
          await tester.scrollUntilVisible(
            find.text('Environmental monitoring for your space.'),
            200,
          );
          await Scrollable.ensureVisible(
            tester.element(
              find.text('Environmental monitoring for your space.'),
            ),
            alignment: 0.04,
          );
          await tester.pumpAndSettle();
          expect(find.text('About this device'), findsOneWidget);
          expect(find.text('Claimed'), findsOneWidget);
          expect(find.text('Provisioned'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (_previewDirectory.isNotEmpty) {
            await tester.runAsync(() async {
              final boundary =
                  boundaryKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2);
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File('$_previewDirectory/details-metadata-phone.png')
                    .writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
          }
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
