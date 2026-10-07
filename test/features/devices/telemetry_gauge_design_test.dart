import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yening_ecos/core/preferences/temperature_unit_preference.dart';
import 'package:yening_ecos/features/devices/device_details_page.dart';
import 'package:yening_ecos/features/devices/models/device_telemetry.dart';
import 'package:yening_ecos/features/devices/models/user_device.dart';
import 'package:yening_ecos/features/devices/services/user_devices_service.dart';
import 'package:yening_ecos/features/devices/widgets/device_telemetry_panel.dart';
import 'package:yening_ecos/features/devices/widgets/telemetry_gauge.dart';
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
    'mobile meters group only temperature units and keep humidity and light side by side',
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
      expect(tester.getTopLeft(humidity).dy, tester.getTopLeft(light).dy);
      expect(tester.getSize(humidity).width, lessThan(180));
      expect(
        tester.getSize(temperature).width,
        greaterThan(tester.getSize(humidity).width),
      );
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
      for (final light in [0.0, 5.0, 5.1, 20.0, 20.1, 100.0]) {
        await tester.pumpWidget(panel(DeviceTelemetry(lightPercent: light)));
        await tester.pumpAndSettle();
        final meter = tester.widget<TelemetryGauge>(
          find.byKey(const ValueKey('light-meter')),
        );
        final expected = light <= 5
            ? meter.lowColor
            : light <= 20
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
    ),
    (
      name: 'home-dark',
      size: const Size(390, 844),
      brightness: Brightness.dark,
      scale: 1.0,
      details: false,
    ),
    (
      name: 'home-tablet',
      size: const Size(1000, 640),
      brightness: Brightness.light,
      scale: 1.0,
      details: false,
    ),
    (
      name: 'details-large-text',
      size: const Size(320, 1000),
      brightness: Brightness.light,
      scale: 1.5,
      details: true,
    ),
  ]) {
    testWidgets(
      '${scene.name} renders real monitoring widgets without overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(scene.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final reading = DeviceTelemetry(
          temperatureCelsius: 28.5,
          humidity: 62.3,
          lightPercent: 78.4,
          lastSeen: DateTime.now(),
          isOnline: true,
          isCloudConnected: true,
        );
        final boundaryKey = GlobalKey();
        final theme = ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: scene.brightness,
          ),
          fontFamily: _previewFont.isNotEmpty ? 'MeterPreview' : null,
          useMaterial3: true,
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
        expect(find.text('62.3%'), findsOneWidget);
        expect(find.text('78.4%'), findsOneWidget);
        expect(find.byType(TemperatureUnitSelector), findsOneWidget);
        expect(tester.takeException(), isNull);
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
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
