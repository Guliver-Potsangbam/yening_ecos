#include <cassert>
#include <cmath>

#include "../main/light_sensor.h"

int main() {
  assert(lightPercentFromAdc(0, 0, 4095) == 0);
  assert(lightPercentFromAdc(4095, 0, 4095) == 100);
  assert(lightPercentFromAdc(2047.5f, 0, 4095) == 50);
  assert(lightPercentFromAdc(4095, 4095, 0) == 0);
  assert(lightPercentFromAdc(0, 4095, 0) == 100);
  assert(lightPercentFromAdc(2047.5f, 4095, 0) == 50);
  // Calibrated sensor endpoints can cover less than the ADC's full scale.
  assert(lightPercentFromAdc(500, 1000, 3000) == 0);
  assert(lightPercentFromAdc(3500, 1000, 3000) == 100);
  assert(lightPercentFromAdc(2500, 3000, 1000) == 25);
  assert(lightPercentFromAdc(3500, 3000, 1000) == 0);
  assert(lightPercentFromAdc(500, 3000, 1000) == 100);
  assert(lightPercentFromAdc(1067, 0, 2000) == 53.4f);
  assert(std::isnan(lightPercentFromAdc(100, 100, 100)));
  assert(std::isnan(lightPercentFromAdc(NAN, 0, 4095)));
  assert(std::isnan(lightPercentFromAdc(INFINITY, 0, 4095)));
}
