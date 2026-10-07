#pragma once

#include <stdint.h>
#include <math.h>

enum class TelemetryMetric : uint8_t { Temperature, Humidity, Light, Count };
constexpr uint8_t TELEMETRY_METRIC_COUNT = static_cast<uint8_t>(TelemetryMetric::Count);

struct MetricReading {
  float value;
  float rawAdc;
  uint32_t sampledAt;
};

inline const char *telemetryMetricName(TelemetryMetric metric) {
  switch (metric) {
    case TelemetryMetric::Temperature: return "temperature";
    case TelemetryMetric::Humidity: return "humidity";
    case TelemetryMetric::Light: return "light";
    default: return "unknown";
  }
}

inline bool validTelemetryReading(TelemetryMetric metric, float value) {
  if (!isfinite(value)) return false;
  switch (metric) {
    case TelemetryMetric::Temperature: return value >= -40 && value <= 80;
    case TelemetryMetric::Humidity:
    case TelemetryMetric::Light: return value >= 0 && value <= 100;
    default: return false;
  }
}

// Keep a fixed cadence despite loop jitter; skip missed slots without bursts.
// An optional minimum spacing also protects sensors with a read cooldown.
class TelemetrySchedule {
 public:
  explicit TelemetrySchedule(uint32_t interval, uint32_t minimumSpacing = 0)
      : interval_(interval), minimumSpacing_(minimumSpacing) {}

  void reset(uint32_t now, bool immediately = false) {
    anchor_ = immediately ? now - interval_ : now;
  }

  bool due(uint32_t now) {
    const uint32_t elapsed = now - anchor_;
    if (interval_ == 0 || elapsed < interval_) return false;
    if (hasSample_ && now - lastSample_ < minimumSpacing_) return false;
    anchor_ += (elapsed / interval_) * interval_;
    lastSample_ = now;
    hasSample_ = true;
    return true;
  }

 private:
  const uint32_t interval_;
  const uint32_t minimumSpacing_;
  uint32_t anchor_ = 0;
  uint32_t lastSample_ = 0;
  bool hasSample_ = false;
};
