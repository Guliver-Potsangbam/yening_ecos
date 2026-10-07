#pragma once

#include <math.h>
#include <stdint.h>

// Relative brightness from two reference ADC readings; not illuminance in lux.
// Reversed endpoints support modules whose voltage falls as brightness rises.
inline float lightPercentFromAdc(float reading, uint16_t darkAdc, uint16_t brightAdc) {
  if (!isfinite(reading) || darkAdc == brightAdc) return NAN;
  float percent = (reading - darkAdc) * 100.0f /
      (static_cast<float>(brightAdc) - darkAdc);
  if (percent < 0.0f) percent = 0.0f;
  if (percent > 100.0f) percent = 100.0f;
  return roundf(percent * 10.0f) / 10.0f;
}
