class DeviceTelemetry {
  const DeviceTelemetry({
    this.temperatureCelsius,
    this.humidity,
    this.lightPercent,
    this.lastSeen,
    this.isOnline,
    this.isCloudConnected,
  });

  final double? temperatureCelsius;
  final double? humidity;
  final double? lightPercent;
  final DateTime? lastSeen;
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

  bool isFreshAt(DateTime now) {
    final seen = lastSeen;
    if (seen == null || isOnline == false || isCloudConnected == false) {
      return false;
    }
    final age = now.difference(seen);
    return age >= const Duration(seconds: -30) &&
        age <= const Duration(seconds: 60);
  }

  factory DeviceTelemetry.fromValue(Object? value) {
    final root = value is Map ? value : const {};
    final readings = root['telemetry'] is Map
        ? root['telemetry'] as Map
        : const {};
    final connectivity = root['connectivity'] is Map
        ? root['connectivity'] as Map
        : const {};

    double? number(Object? value) {
      if (value is! num) return null;
      final converted = value.toDouble();
      return converted.isFinite ? converted : null;
    }

    DateTime? seen;
    final timestamp = number(connectivity['lastSeen']);
    if (timestamp != null && timestamp >= 0 && timestamp <= 8640000000000000) {
      seen = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
    }
    final light = number(readings['light']);
    return DeviceTelemetry(
      temperatureCelsius: number(readings['temperature']),
      humidity: number(readings['humidity']),
      lightPercent: light != null && light >= 0 && light <= 100 ? light : null,
      lastSeen: seen,
      isOnline: connectivity['isOnline'] is bool
          ? connectivity['isOnline'] as bool
          : null,
    );
  }
}
