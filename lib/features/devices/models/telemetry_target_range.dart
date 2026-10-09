enum TelemetryMetric {
  temperature('Temperature', -40, 80),
  humidity('Humidity', 0, 100),
  light('Light', 0, 100);

  const TelemetryMetric(this.label, this.minimum, this.maximum);
  final String label;
  final double minimum;
  final double maximum;
}

enum TargetPosition { below, within, above }

/// User-selected bounds in the metric's canonical unit (Celsius or percent).
class TelemetryTargetRange {
  const TelemetryTargetRange(this.minimum, this.maximum);
  final double minimum;
  final double maximum;

  bool isValidFor(TelemetryMetric metric) =>
      minimum.isFinite &&
      maximum.isFinite &&
      minimum >= metric.minimum &&
      maximum <= metric.maximum &&
      minimum < maximum;

  TargetPosition position(double value) => value < minimum
      ? TargetPosition.below
      : value > maximum
      ? TargetPosition.above
      : TargetPosition.within;

  double distance(double value) => value < minimum
      ? minimum - value
      : value > maximum
      ? value - maximum
      : 0;

  TelemetryTargetRange converted(double Function(double) convert) =>
      TelemetryTargetRange(convert(minimum), convert(maximum));

  Map<String, double> toJson() => {'minimum': minimum, 'maximum': maximum};

  static TelemetryTargetRange? fromJson(Object? value, TelemetryMetric metric) {
    if (value is! Map || value['minimum'] is! num || value['maximum'] is! num) {
      return null;
    }
    final range = TelemetryTargetRange(
      (value['minimum'] as num).toDouble(),
      (value['maximum'] as num).toDouble(),
    );
    return range.isValidFor(metric) ? range : null;
  }
}
