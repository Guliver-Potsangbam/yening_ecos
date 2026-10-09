import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yening_ecos/core/preferences/telemetry_target_preference.dart';
import 'package:yening_ecos/core/preferences/temperature_unit_preference.dart';
import 'package:yening_ecos/core/ui/app_theme.dart';
import 'package:yening_ecos/features/devices/models/device_telemetry.dart';
import 'package:yening_ecos/features/devices/models/telemetry_target_range.dart';
import 'package:yening_ecos/features/devices/widgets/device_telemetry_panel.dart';
import 'package:yening_ecos/features/devices/widgets/telemetry_gauge.dart';

void main() {
  const previewFont = String.fromEnvironment('TELEMETRY_PREVIEW_FONT');
  setUpAll(() async {
    if (previewFont.isNotEmpty) {
      final bytes = await File(previewFont).readAsBytes();
      await (FontLoader(
        'MeterPreview',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  final now = DateTime(2026, 10, 8, 12);
  late TelemetryTargetPreference targets;
  late TemperatureUnitPreference units;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    targets = TelemetryTargetPreference(currentUserUid: () => 'owner');
    units = TemperatureUnitPreference();
    await units.load();
  });
  tearDown(() {
    targets.dispose();
    units.dispose();
  });

  DeviceTelemetry sample({DateTime? timestamp, bool online = true}) =>
      DeviceTelemetry(
        temperatureCelsius: 28.5,
        humidity: 62.3,
        lightPercent: 78.4,
        temperatureUpdatedAt: timestamp ?? now,
        humidityUpdatedAt: timestamp ?? now,
        lightUpdatedAt: timestamp ?? now,
        lastSeen: now,
        isOnline: online,
      );
  Widget view(
    DeviceTelemetry reading, {
    String deviceId = 'device-1',
    Key? boundary,
  }) => RepaintBoundary(
    key: boundary,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: previewFont.isEmpty
          ? AppTheme.light()
          : AppTheme.light().copyWith(
              textTheme: AppTheme.light().textTheme.apply(
                fontFamily: 'MeterPreview',
              ),
              primaryTextTheme: AppTheme.light().primaryTextTheme.apply(
                fontFamily: 'MeterPreview',
              ),
            ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: DeviceTelemetryPanel(
            deviceId: deviceId,
            telemetrySource: (_) => Stream.value(reading),
            unitPreference: units,
            targetPreference: targets,
            now: () => now,
          ),
        ),
      ),
    ),
  );
  Future<void> edit(
    WidgetTester tester,
    TelemetryMetric metric,
    String low,
    String high,
  ) async {
    final button = find.byKey(ValueKey('edit-target-${metric.name}'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('target-minimum')), low);
    await tester.enterText(find.byKey(const ValueKey('target-maximum')), high);
    await tester.ensureVisible(find.text('Save target'));
    await tester.tap(find.text('Save target'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pumpAndSettle();
  }

  test('target comparison includes both boundaries and returns distance to the nearest one', () {
    const range = TelemetryTargetRange(18, 24);
    expect(range.position(18), TargetPosition.within);
    expect(range.position(24), TargetPosition.within);
    expect(range.distance(20), 0);
    expect(range.position(16), TargetPosition.below);
    expect(range.distance(16), 2);
    expect(range.position(28.5), TargetPosition.above);
    expect(range.distance(28.5), 4.5);
  });
  test('malformed and physically impossible target ranges are rejected', () {
    for (final payload in [
      null,
      {},
      {'minimum': '20', 'maximum': 30},
      {'minimum': 30, 'maximum': 20},
      {'minimum': 20, 'maximum': 20},
      {'minimum': -41, 'maximum': 80},
      {'minimum': 20, 'maximum': double.infinity},
    ]) {
      expect(
        TelemetryTargetRange.fromJson(payload, TelemetryMetric.temperature),
        isNull,
      );
    }
    expect(
      const TelemetryTargetRange(0, 100).isValidFor(TelemetryMetric.light),
      isTrue,
    );
    expect(
      const TelemetryTargetRange(-1, 100).isValidFor(TelemetryMetric.humidity),
      isFalse,
    );
  });
  test(
    'saving, reloading and removing targets preserves independent metrics',
    () async {
      await targets.setRange(
        'device-1',
        TelemetryMetric.temperature,
        const TelemetryTargetRange(18, 24),
      );
      await targets.setRange(
        'device-1',
        TelemetryMetric.humidity,
        const TelemetryTargetRange(80, 95),
      );
      final reloaded = TelemetryTargetPreference(currentUserUid: () => 'owner');
      addTearDown(reloaded.dispose);
      await reloaded.load('device-1');
      expect(
        reloaded.rangeFor('device-1', TelemetryMetric.temperature)!.minimum,
        18,
      );
      await reloaded.setRange('device-1', TelemetryMetric.temperature, null);
      expect(
        reloaded.rangeFor('device-1', TelemetryMetric.temperature),
        isNull,
      );
      expect(
        reloaded.rangeFor('device-1', TelemetryMetric.humidity)!.maximum,
        95,
      );
    },
  );
  test('different accounts and devices have separate targets', () async {
    var uid = 'first';
    final scoped = TelemetryTargetPreference(currentUserUid: () => uid);
    addTearDown(scoped.dispose);
    await scoped.setRange(
      'device-1',
      TelemetryMetric.temperature,
      const TelemetryTargetRange(18, 24),
    );
    expect(scoped.rangeFor('device-2', TelemetryMetric.temperature), isNull);
    uid = 'second';
    expect(scoped.rangeFor('device-1', TelemetryMetric.temperature), isNull);
    await scoped.setRange(
      'device-1',
      TelemetryMetric.temperature,
      const TelemetryTargetRange(20, 30),
    );
    uid = 'first';
    expect(
      scoped.rangeFor('device-1', TelemetryMetric.temperature)!.maximum,
      24,
    );
  });
  test('concurrent edits do not overwrite sibling targets', () async {
    await Future.wait([
      targets.setRange(
        'device-1',
        TelemetryMetric.temperature,
        const TelemetryTargetRange(18, 24),
      ),
      targets.setRange(
        'device-1',
        TelemetryMetric.humidity,
        const TelemetryTargetRange(80, 95),
      ),
      targets.setRange(
        'device-1',
        TelemetryMetric.light,
        const TelemetryTargetRange(0, 100),
      ),
    ]);
    for (final metric in TelemetryMetric.values) {
      expect(targets.rangeFor('device-1', metric), isNotNull);
    }
  });
  test(
    'storage errors and invalid edits never publish an unsaved target',
    () async {
      final broken = TelemetryTargetPreference(
        currentUserUid: () => 'owner',
        loadPreferences: () async => throw StateError('Storage unavailable'),
      );
      addTearDown(broken.dispose);
      await expectLater(
        broken.setRange(
          'device-1',
          TelemetryMetric.humidity,
          const TelemetryTargetRange(80, 95),
        ),
        throwsStateError,
      );
      expect(broken.rangeFor('device-1', TelemetryMetric.humidity), isNull);
      await expectLater(
        targets.setRange(
          'device-1',
          TelemetryMetric.humidity,
          const TelemetryTargetRange(95, 80),
        ),
        throwsArgumentError,
      );
    },
  );

  testWidgets(
    'users set, validate, edit and remove a target from its sensor card',
    (tester) async {
      await tester.pumpWidget(view(sample()));
      await tester.pumpAndSettle();
      expect(find.text('Session low / high'), findsNothing);
      expect(find.text('First reading'), findsNothing);
      await edit(tester, TelemetryMetric.temperature, '24', '18');
      expect(find.text('Maximum must be greater than minimum'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('target-minimum')),
        '18',
      );
      await tester.enterText(
        find.byKey(const ValueKey('target-maximum')),
        '24',
      );
      await tester.tap(find.text('Save target'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pumpAndSettle();
      expect(find.text('4.5 °C above'), findsOneWidget);
      expect(find.text('Above target'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('edit-target-temperature')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove target'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pumpAndSettle();
      expect(targets.rangeFor('device-1', TelemetryMetric.temperature), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Fahrenheit targets and deviation keep canonical Celsius values',
    (tester) async {
      units.value = TemperatureUnit.fahrenheit;
      await tester.pumpWidget(view(sample()));
      await tester.pumpAndSettle();
      await edit(tester, TelemetryMetric.temperature, '68', '77');
      final range = targets.rangeFor('device-1', TelemetryMetric.temperature)!;
      expect(range.minimum, 20);
      expect(range.maximum, 25);
      expect(find.text('6.3 °F above'), findsOneWidget);
      await tester.tap(find.text('°C'));
      await tester.pumpAndSettle();
      expect(find.text('20.0–25.0 °C'), findsOneWidget);
      expect(find.text('3.5 °C above'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'saving an unchanged rounded Fahrenheit range does not drift Celsius bounds',
    (tester) async {
      await tester.runAsync(
        () => targets.setRange(
          'device-1',
          TelemetryMetric.temperature,
          const TelemetryTargetRange(20.15, 24.15),
        ),
      );
      units.value = TemperatureUnit.fahrenheit;
      await tester.pumpWidget(view(sample()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit-target-temperature')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save target'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pumpAndSettle();
      expect(
        targets.rangeFor('device-1', TelemetryMetric.temperature)!.minimum,
        20.15,
      );
      expect(
        targets.rangeFor('device-1', TelemetryMetric.temperature)!.maximum,
        24.15,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'targets update across views while stale and offline checks pause',
    (tester) async {
      await tester.pumpWidget(view(sample()));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => targets.setRange(
          'device-1',
          TelemetryMetric.humidity,
          const TelemetryTargetRange(80, 95),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('17.7 pp below'), findsOneWidget);
      expect(find.text('Below target'), findsOneWidget);
      final gauge = tester.widget<TelemetryGauge>(
        find.byKey(const ValueKey('humidity-meter')),
      );
      expect(gauge.readingColor, gauge.highColor);
      await tester.pumpWidget(
        view(sample(timestamp: now.subtract(const Duration(minutes: 2)))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Target check paused'), findsOneWidget);
      expect(find.text('17.7 pp below'), findsNothing);
      await tester.pumpWidget(view(sample(online: false)));
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsNWidgets(3));
      expect(find.text('Last reading'), findsNWidgets(3));
      expect(find.text('17.7 pp below'), findsNothing);
      await tester.pumpWidget(
        view(DeviceTelemetry(humidity: 62.3, lastSeen: now, isOnline: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Target check paused'), findsOneWidget);
      await tester.pumpWidget(
        view(
          DeviceTelemetry(
            humidity: 62.3,
            humidityUpdatedAt: now,
            lastSeen: now,
            isOnline: true,
            isCloudConnected: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Target check paused'), findsOneWidget);
      await tester.pumpWidget(view(sample(), deviceId: 'device-2'));
      await tester.pumpAndSettle();
      expect(find.text('80.0–95.0 % RH'), findsNothing);
      await tester.pumpWidget(view(sample()));
      await tester.pumpAndSettle();
      expect(find.text('80.0–95.0 % RH'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'live samples update target verdicts without changing the saved range',
    (tester) async {
      await tester.runAsync(
        () => targets.setRange(
          'device-1',
          TelemetryMetric.temperature,
          const TelemetryTargetRange(18, 24),
        ),
      );
      final samples = StreamController<DeviceTelemetry>.broadcast();
      addTearDown(samples.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DeviceTelemetryPanel(
                deviceId: 'device-1',
                targetPreference: targets,
                unitPreference: units,
                telemetrySource: (_) => samples.stream,
                now: () => now,
              ),
            ),
          ),
        ),
      );
      for (final entry in [
        (28.0, 'Above target'),
        (22.0, 'Within target'),
        (16.0, 'Below target'),
      ]) {
        samples.add(
          DeviceTelemetry(
            temperatureCelsius: entry.$1,
            temperatureUpdatedAt: now,
            lastSeen: now,
            isOnline: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(entry.$2), findsOneWidget);
        expect(
          targets.rangeFor('device-1', TelemetryMetric.temperature)!.maximum,
          24,
        );
      }
      expect(find.text('2.0 °C below'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'full-scale brightness target remains readable and cards retain equal dimensions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(
        () => targets.setRange(
          'device-1',
          TelemetryMetric.temperature,
          const TelemetryTargetRange(20, 25),
        ),
      );
      await tester.runAsync(
        () => targets.setRange(
          'device-1',
          TelemetryMetric.humidity,
          const TelemetryTargetRange(80, 95),
        ),
      );
      await tester.runAsync(
        () => targets.setRange(
          'device-1',
          TelemetryMetric.light,
          const TelemetryTargetRange(0, 100),
        ),
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(view(sample(), boundary: boundary));
      await tester.pumpAndSettle();
      final temperature = find.byKey(const ValueKey('temperature-meter'));
      final humidity = find.byKey(const ValueKey('humidity-meter'));
      final light = find.byKey(const ValueKey('light-meter'));
      expect(tester.getSize(temperature), tester.getSize(humidity));
      expect(tester.getSize(temperature), tester.getSize(light));
      expect(
        tester.widget<TelemetryGauge>(light).readingColor,
        tester.widget<TelemetryGauge>(light).color,
      );
      final semantics = tester.ensureSemantics();
      await tester.pump();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
      expect(tester.takeException(), isNull);
      const preview = String.fromEnvironment('TELEMETRY_PREVIEW_DIR');
      if (preview.isNotEmpty) {
        final rendered = await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final directory = Directory(preview)..createSync(recursive: true);
          await File('${directory.path}/configured-targets-phone.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          return true;
        });
        expect(rendered, isTrue);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
