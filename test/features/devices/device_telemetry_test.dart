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
        4.9: 'Dark',
        5: 'Dark',
        5.1: 'Low light',
        19.9: 'Low light',
        20: 'Low light',
        20.1: 'Bright',
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
    expect(result.isOnline, isTrue);
  });

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
