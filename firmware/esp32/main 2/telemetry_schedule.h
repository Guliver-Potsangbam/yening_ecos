#pragma once

#include <stdint.h>

struct TelemetrySample {
  float temperature;
  float humidity;
  float lightAdc;
  float lightPercent;
  uint32_t sampledAt;
};

// Keep a fixed cadence despite loop jitter; skip missed slots without bursts.
class TelemetrySchedule {
 public:
  explicit TelemetrySchedule(uint32_t interval) : interval_(interval) {}

  void reset(uint32_t now, bool immediately = false) {
    anchor_ = immediately ? now - interval_ : now;
  }

  bool due(uint32_t now) {
    const uint32_t elapsed = now - anchor_;
    if (interval_ == 0 || elapsed < interval_) return false;
    anchor_ += (elapsed / interval_) * interval_;
    return true;
  }

 private:
  const uint32_t interval_;
  uint32_t anchor_ = 0;
};
