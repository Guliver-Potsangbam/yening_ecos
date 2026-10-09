enum DeviceConnectionState { online, offline, reconnecting, waiting }

class DeviceTelemetry {
  // Five missed two-second upload intervals before inferring device offline.
  static const heartbeatTimeout = Duration(seconds: 10);

  const DeviceTelemetry({
    this.temperatureCelsius,
    this.humidity,
    this.lightPercent,
    this.temperatureUpdatedAt,
    this.humidityUpdatedAt,
    this.lightUpdatedAt,
    this.lastSeen,
    this.isOnline,
    this.isCloudConnected,
  });

  final double? temperatureCelsius;
  final double? humidity;
  final double? lightPercent;
  final DateTime? temperatureUpdatedAt;
  final DateTime? humidityUpdatedAt;
  final DateTime? lightUpdatedAt;
  final DateTime? lastSeen;

  /// Last device-reported flag; it can remain true after abrupt disconnection.
  /// Use isFreshAt(now) to check the heartbeat before displaying online status.
  final bool? isOnline;
  final bool? isCloudConnected;

  String? get lightLabel {
    final light = lightPercent;
    if (light == null || !light.isFinite || light < 0 || light > 100) {
      return null;
    }
    if (light <= 23) return 'Dark';
    if (light <= 45) return 'Low light';
    return 'Bright';
  }

  bool get hasReadings =>
      temperatureCelsius != null || humidity != null || lightPercent != null;

  DeviceConnectionState connectionStateAt(DateTime now) {
    if (isCloudConnected == false) return DeviceConnectionState.reconnecting;
    final hasHeartbeat = (lastSeen?.millisecondsSinceEpoch ?? 0) > 0;
    if (isOnline == false || (hasHeartbeat && !isFreshAt(now))) {
      return DeviceConnectionState.offline;
    }
    return isFreshAt(now)
        ? DeviceConnectionState.online
        : DeviceConnectionState.waiting;
  }

  bool isFreshAt(DateTime now) {
    return _isTimestampFreshAt(lastSeen, now, maximumAge: heartbeatTimeout);
  }

  bool isTemperatureFreshAt(DateTime now) => _isReadingFreshAt(
    temperatureCelsius,
    temperatureUpdatedAt,
    now,
    minimum: -40,
    maximum: 80,
  );

  bool isHumidityFreshAt(DateTime now) => _isReadingFreshAt(
    humidity,
    humidityUpdatedAt,
    now,
    minimum: 0,
    maximum: 100,
  );

  bool isLightFreshAt(DateTime now) => _isReadingFreshAt(
    lightPercent,
    lightUpdatedAt,
    now,
    minimum: 0,
    maximum: 100,
  );

  bool _isReadingFreshAt(
    double? value,
    DateTime? updatedAt,
    DateTime now, {
    required double minimum,
    required double maximum,
  }) =>
      value != null &&
      value.isFinite &&
      value >= minimum &&
      value <= maximum &&
      _isTimestampFreshAt(updatedAt, now);

  bool _isTimestampFreshAt(
    DateTime? updatedAt,
    DateTime now, {
    Duration maximumAge = const Duration(seconds: 60),
  }) {
    if (updatedAt == null ||
        updatedAt.millisecondsSinceEpoch <= 0 ||
        isOnline == false ||
        isCloudConnected == false) {
      return false;
    }
    final age = now.difference(updatedAt);
    return age >= const Duration(seconds: -30) && age <= maximumAge;
  }

  factory DeviceTelemetry.fromValue(Object? value) {
    final root = value is Map ? value : const {};
    final readings = root['telemetry'] is Map
        ? root['telemetry'] as Map
        : const {};
    final connectivity = root['connectivity'] is Map
        ? root['connectivity'] as Map
        : const {};

    final seen = _timestamp(connectivity['lastSeen']);
    // Once independent records exist, a shared heartbeat cannot date scalar
    // siblings that have not yet migrated to their own update timestamps.
    final legacyUpdatedAt = readings.values.any((reading) => reading is Map)
        ? null
        : seen;
    final temperature = _SensorReading.fromValue(
      readings['temperature'],
      legacyUpdatedAt: legacyUpdatedAt,
      minimum: -40,
      maximum: 80,
    );
    final humidity = _SensorReading.fromValue(
      readings['humidity'],
      legacyUpdatedAt: legacyUpdatedAt,
      minimum: 0,
      maximum: 100,
    );
    final light = _SensorReading.fromValue(
      readings['light'],
      legacyUpdatedAt: legacyUpdatedAt,
      minimum: 0,
      maximum: 100,
    );
    return DeviceTelemetry(
      temperatureCelsius: temperature.value,
      humidity: humidity.value,
      lightPercent: light.value,
      temperatureUpdatedAt: temperature.updatedAt,
      humidityUpdatedAt: humidity.updatedAt,
      lightUpdatedAt: light.updatedAt,
      lastSeen: seen,
      isOnline: connectivity['isOnline'] is bool
          ? connectivity['isOnline'] as bool
          : null,
    );
  }
}

double? _finiteNumber(Object? value) {
  if (value is! num) return null;
  final converted = value.toDouble();
  return converted.isFinite ? converted : null;
}

DateTime? _timestamp(Object? value, {bool allowZero = true}) {
  final milliseconds = _finiteNumber(value);
  if (milliseconds == null ||
      milliseconds < (allowZero ? 0 : 1) ||
      milliseconds > 8640000000000000 ||
      milliseconds != milliseconds.truncateToDouble()) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(milliseconds.toInt(), isUtc: true);
}

class _SensorReading {
  const _SensorReading({this.value, this.updatedAt});

  final double? value;
  final DateTime? updatedAt;

  factory _SensorReading.fromValue(
    Object? raw, {
    required DateTime? legacyUpdatedAt,
    required double minimum,
    required double maximum,
  }) {
    final nested = raw is Map;
    final value = _finiteNumber(nested ? raw['value'] : raw);
    final updatedAt = nested
        ? _timestamp(raw['updatedAt'], allowZero: false)
        : legacyUpdatedAt;
    if (value == null || value < minimum || value > maximum) {
      return const _SensorReading();
    }
    // An incomplete new record cannot borrow a heartbeat from another sensor.
    if (nested && updatedAt == null) return const _SensorReading();
    return _SensorReading(value: value, updatedAt: updatedAt);
  }
}
