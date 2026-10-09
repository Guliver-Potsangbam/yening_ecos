import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TemperatureUnit {
  celsius('Celsius', '°C'),
  fahrenheit('Fahrenheit', '°F');

  const TemperatureUnit(this.label, this.symbol);
  final String label;
  final String symbol;

  double fromCelsius(double value) =>
      this == celsius ? value : value * 9 / 5 + 32;

  /// Differences scale between units without the absolute-temperature offset.
  double differenceFromCelsius(double value) =>
      this == celsius ? value : value * 9 / 5;
}

class TemperatureUnitPreference extends ValueNotifier<TemperatureUnit> {
  TemperatureUnitPreference({
    Future<SharedPreferences> Function()? loadPreferences,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance,
       super(TemperatureUnit.celsius);

  static final instance = TemperatureUnitPreference();
  static const storageKey = 'temperature_unit';
  final Future<SharedPreferences> Function() _loadPreferences;
  Future<void> _writes = Future.value();

  Future<void> load() async {
    try {
      final preferences = await _loadPreferences();
      value =
          preferences.getString(storageKey) == TemperatureUnit.fahrenheit.name
          ? TemperatureUnit.fahrenheit
          : TemperatureUnit.celsius;
    } catch (_) {
      // Preference storage must not prevent the app from opening.
      value = TemperatureUnit.celsius;
    }
  }

  Future<void> setUnit(TemperatureUnit unit) {
    value = unit;
    // Serialize changes so rapid toggles cannot persist an older selection.
    _writes = _writes.catchError((Object _) {}).then((_) async {
      final preferences = await _loadPreferences();
      if (!await preferences.setString(storageKey, unit.name)) {
        throw StateError('Temperature preference could not be saved.');
      }
    });
    return _writes;
  }
}
