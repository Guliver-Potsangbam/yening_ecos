import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yening_ecos/core/preferences/temperature_unit_preference.dart';
import 'package:yening_ecos/features/devices/models/device_telemetry.dart';

void main() {
  test(
    'light labels classify exact boundaries and reject unavailable readings',
    () {
      for (final entry in <double, String>{
        0: 'Dark',
        22.9: 'Dark',
        23: 'Dark',
        23.1: 'Low light',
        44.9: 'Low light',
        45: 'Low light',
        45.1: 'Bright',
        100: 'Bright',
      }.entries) {
        expect(
          DeviceTelemetry(lightPercent: entry.key).lightLabel,
          entry.value,
        );
      }
      for (final value in [null, -0.1, 100.1, double.nan, double.infinity]) {
        expect(DeviceTelemetry(lightPercent: value).lightLabel, isNull);
      }
    },
  );

  test('parses the ESP32 telemetry and connectivity payload', () {
    final result = DeviceTelemetry.fromValue({
      'telemetry': {'temperature': 25, 'humidity': 61.5, 'light': 43.2},
      'connectivity': {'isOnline': true, 'lastSeen': 1700000000000},
    });
    expect(result.temperatureCelsius, 25);
    expect(result.humidity, 61.5);
    expect(result.lightPercent, 43.2);
    expect(result.lastSeen!.millisecondsSinceEpoch, 1700000000000);
    expect(result.temperatureUpdatedAt, result.lastSeen);
    expect(result.humidityUpdatedAt, result.lastSeen);
    expect(result.lightUpdatedAt, result.lastSeen);
    expect(result.isOnline, isTrue);
  });

  test('parses independent value and update time pairs for all sensors', () {
    const startedAt = 1700000000000;
    final result = DeviceTelemetry.fromValue({
      'telemetry': {
        'temperature': {'value': 25, 'updatedAt': startedAt},
        'humidity': {'value': 61.5, 'updatedAt': startedAt + 100},
        'light': {'value': 43.2, 'updatedAt': startedAt + 200},
      },
      'connectivity': {'isOnline': true, 'lastSeen': startedAt + 300},
    });
    expect(result.temperatureCelsius, 25);
    expect(result.humidity, 61.5);
    expect(result.lightPercent, 43.2);
    expect(result.temperatureUpdatedAt!.millisecondsSinceEpoch, startedAt);
    expect(result.humidityUpdatedAt!.millisecondsSinceEpoch, startedAt + 100);
    expect(result.lightUpdatedAt!.millisecondsSinceEpoch, startedAt + 200);
    expect(result.lastSeen!.millisecondsSinceEpoch, startedAt + 300);
    expect(result.temperatureUpdatedAt!.isUtc, isTrue);
  });

  test(
    'mixed rollout records keep scalar readings without inferring update times',
    () {
      const startedAt = 1700000000000;
      final result = DeviceTelemetry.fromValue({
        'telemetry': {
          'temperature': 25,
          'humidity': {'value': 61.5, 'updatedAt': startedAt - 2000},
          'light': {'value': 43.2},
        },
        'connectivity': {'isOnline': true, 'lastSeen': startedAt},
      });
      expect(result.temperatureCelsius, 25);
      expect(result.temperatureUpdatedAt, isNull);
      expect(result.humidity, 61.5);
      expect(
        result.humidityUpdatedAt!.millisecondsSinceEpoch,
        startedAt - 2000,
      );
      expect(result.lightPercent, isNull);
      expect(result.lightUpdatedAt, isNull);
    },
  );

  test(
    'malformed sensor pairs cannot borrow a healthy heartbeat timestamp',
    () {
      const validTime = 1700000000000;
      for (final invalidTime in [
        null,
        0,
        -1,
        1700000000000.5,
        8640000000000001,
        '1700000000000',
        true,
        double.nan,
        double.infinity,
        {'.sv': 'timestamp'},
      ]) {
        final result = DeviceTelemetry.fromValue({
          'telemetry': {
            'temperature': {'value': 25, 'updatedAt': invalidTime},
            'humidity': {'value': 61.5, 'updatedAt': invalidTime},
            'light': {'value': 43.2, 'updatedAt': invalidTime},
          },
          'connectivity': {'isOnline': true, 'lastSeen': validTime},
        });
        expect(result.hasReadings, isFalse, reason: 'timestamp: $invalidTime');
        expect(result.temperatureUpdatedAt, isNull);
        expect(result.humidityUpdatedAt, isNull);
        expect(result.lightUpdatedAt, isNull);
        expect(result.lastSeen!.millisecondsSinceEpoch, validTime);
      }
      for (final invalidPair in [
        null,
        [],
        <String, Object?>{},
        {'updatedAt': validTime},
        {'value': null, 'updatedAt': validTime},
        {'value': '25', 'updatedAt': validTime},
        {'value': double.nan, 'updatedAt': validTime},
      ]) {
        final result = DeviceTelemetry.fromValue({
          'telemetry': {
            'temperature': invalidPair,
            'humidity': invalidPair,
            'light': invalidPair,
          },
          'connectivity': {'lastSeen': validTime},
        });
        expect(result.hasReadings, isFalse, reason: 'record: $invalidPair');
        expect(result.temperatureUpdatedAt, isNull);
        expect(result.humidityUpdatedAt, isNull);
        expect(result.lightUpdatedAt, isNull);
      }
    },
  );

  test(
    'seed heartbeat zero remains parseable without making sensor records valid',
    () {
      final result = DeviceTelemetry.fromValue({
        'telemetry': {
          'temperature': {'value': 25, 'updatedAt': 0},
        },
        'connectivity': {'isOnline': false, 'lastSeen': 0},
      });
      expect(result.lastSeen!.millisecondsSinceEpoch, 0);
      expect(result.temperatureCelsius, isNull);
      expect(result.temperatureUpdatedAt, isNull);
      expect(result.hasReadings, isFalse);
    },
  );

  test('legacy and independent readings enforce physical sensor ranges', () {
    for (final nested in [false, true]) {
      Object record(double value) =>
          nested ? {'value': value, 'updatedAt': 1700000000000} : value;
      for (final values in [
        [-40.1, -0.1, -0.1],
        [80.1, 100.1, 100.1],
        [double.infinity, double.infinity, double.infinity],
      ]) {
        final result = DeviceTelemetry.fromValue({
          'telemetry': {
            'temperature': record(values[0]),
            'humidity': record(values[1]),
            'light': record(values[2]),
          },
        });
        expect(result.hasReadings, isFalse);
        expect(result.temperatureUpdatedAt, isNull);
        expect(result.humidityUpdatedAt, isNull);
        expect(result.lightUpdatedAt, isNull);
      }
      for (final values in [
        [-40.0, 0.0, 0.0],
        [80.0, 100.0, 100.0],
      ]) {
        final result = DeviceTelemetry.fromValue({
          'telemetry': {
            'temperature': record(values[0]),
            'humidity': record(values[1]),
            'light': record(values[2]),
          },
        });
        expect(result.temperatureCelsius, values[0]);
        expect(result.humidity, values[1]);
        expect(result.lightPercent, values[2]);
      }
    }
  });

  test('a healthy device heartbeat cannot refresh one stale sensor', () {
    final now = DateTime.utc(2026, 10, 7, 12);
    final reading = DeviceTelemetry(
      temperatureCelsius: 25,
      humidity: 61.5,
      lightPercent: 43.2,
      temperatureUpdatedAt: now.subtract(const Duration(seconds: 61)),
      humidityUpdatedAt: now.subtract(const Duration(seconds: 2)),
      lightUpdatedAt: now,
      lastSeen: now,
      isOnline: true,
      isCloudConnected: true,
    );
    expect(reading.isFreshAt(now), isTrue);
    expect(reading.isTemperatureFreshAt(now), isFalse);
    expect(reading.isHumidityFreshAt(now), isTrue);
    expect(reading.isLightFreshAt(now), isTrue);
    expect(
      reading.isHumidityFreshAt(now.add(const Duration(seconds: 59))),
      isFalse,
    );
    expect(
      reading.isLightFreshAt(now.add(const Duration(seconds: 61))),
      isFalse,
    );
  });

  test(
    'sensor freshness requires a valid reading, its own time and connection',
    () {
      final now = DateTime.utc(2026, 10, 7, 12);
      for (final record in [
        DeviceTelemetry(temperatureUpdatedAt: now),
        DeviceTelemetry(temperatureCelsius: 25, lastSeen: now),
        DeviceTelemetry(
          temperatureCelsius: double.nan,
          temperatureUpdatedAt: now,
        ),
        DeviceTelemetry(temperatureCelsius: 80.1, temperatureUpdatedAt: now),
        DeviceTelemetry(
          temperatureCelsius: 25,
          temperatureUpdatedAt: now,
          isOnline: false,
        ),
        DeviceTelemetry(
          temperatureCelsius: 25,
          temperatureUpdatedAt: now,
          isCloudConnected: false,
        ),
        DeviceTelemetry(
          temperatureCelsius: 25,
          temperatureUpdatedAt: now.add(const Duration(seconds: 31)),
        ),
      ]) {
        expect(record.isTemperatureFreshAt(now), isFalse);
      }
      expect(
        DeviceTelemetry(
          temperatureCelsius: 25,
          temperatureUpdatedAt: now.add(const Duration(seconds: 30)),
        ).isTemperatureFreshAt(now),
        isTrue,
      );
    },
  );

  test('light-only readings accept zero and reject invalid percentages', () {
    for (final value in [0, 53.2, 100]) {
      final result = DeviceTelemetry.fromValue({
        'telemetry': {'light': value},
      });
      expect(result.lightPercent, value);
      expect(result.hasReadings, isTrue);
    }
    for (final value in [
      null,
      -0.1,
      100.1,
      4095,
      '50',
      true,
      double.nan,
      double.infinity,
    ]) {
      final result = DeviceTelemetry.fromValue({
        'telemetry': {'light': value},
      });
      expect(result.lightPercent, isNull);
      expect(result.hasReadings, isFalse);
    }
  });

  test('missing, nonnumeric and nonfinite readings never become zero', () {
    for (final raw in [
      null,
      false,
      [],
      {'telemetry': 'invalid'},
      {
        'telemetry': {'temperature': '25', 'humidity': double.nan},
      },
    ]) {
      final result = DeviceTelemetry.fromValue(raw);
      expect(result.temperatureCelsius, isNull);
      expect(result.humidity, isNull);
      expect(result.hasReadings, isFalse);
    }
    expect(
      DeviceTelemetry.fromValue({
        'telemetry': {'temperature': 0, 'humidity': 0},
      }).hasReadings,
      isTrue,
    );
  });

  test('freshness expires even when the firmware online flag remains true', () {
    final now = DateTime(2026, 10, 4, 12);
    final reading = DeviceTelemetry(lastSeen: now, isOnline: true);
    expect(reading.isFreshAt(now.add(const Duration(seconds: 60))), isTrue);
    expect(reading.isFreshAt(now.add(const Duration(seconds: 61))), isFalse);
    expect(
      DeviceTelemetry(lastSeen: now, isOnline: false).isFreshAt(now),
      isFalse,
    );
    expect(
      DeviceTelemetry(lastSeen: now, isCloudConnected: false).isFreshAt(now),
      isFalse,
    );
    expect(const DeviceTelemetry().isFreshAt(now), isFalse);
  });

  test('Celsius converts correctly including freezing, boiling and negative values', () {
    expect(TemperatureUnit.celsius.fromCelsius(25), 25);
    expect(TemperatureUnit.fahrenheit.fromCelsius(0), 32);
    expect(TemperatureUnit.fahrenheit.fromCelsius(100), 212);
    expect(TemperatureUnit.fahrenheit.fromCelsius(-40), -40);
    expect(TemperatureUnit.fahrenheit.fromCelsius(25), 77);
  });

  test(
    'unit preference defaults to Celsius and persists across app sessions',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preference = TemperatureUnitPreference();
      await preference.load();
      expect(preference.value, TemperatureUnit.celsius);
      await preference.setUnit(TemperatureUnit.fahrenheit);
      final nextSession = TemperatureUnitPreference();
      await nextSession.load();
      expect(nextSession.value, TemperatureUnit.fahrenheit);
      preference.dispose();
      nextSession.dispose();
    },
  );

  test('rapid unit changes persist the final selection', () async {
    SharedPreferences.setMockInitialValues({});
    final preference = TemperatureUnitPreference();
    await Future.wait([
      preference.setUnit(TemperatureUnit.fahrenheit),
      preference.setUnit(TemperatureUnit.celsius),
    ]);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString(TemperatureUnitPreference.storageKey), 'celsius');
    expect(preference.value, TemperatureUnit.celsius);
    preference.dispose();
  });
}
