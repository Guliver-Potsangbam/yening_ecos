#include <cassert>
#include <initializer_list>
#include <stdint.h>

#include "../main/telemetry_schedule.h"

int main() {
  // Independent records have separate bounds; one failed sensor cannot turn
  // another sensor's valid reading into an invalid batch.
  assert(validTelemetryReading(TelemetryMetric::Temperature, -40));
  assert(validTelemetryReading(TelemetryMetric::Temperature, 80));
  assert(!validTelemetryReading(TelemetryMetric::Temperature, -40.1f));
  assert(!validTelemetryReading(TelemetryMetric::Temperature, 80.1f));
  for (TelemetryMetric metric : {TelemetryMetric::Humidity, TelemetryMetric::Light}) {
    assert(validTelemetryReading(metric, 0));
    assert(validTelemetryReading(metric, 100));
    assert(!validTelemetryReading(metric, -0.1f));
    assert(!validTelemetryReading(metric, 100.1f));
    assert(!validTelemetryReading(metric, NAN));
    assert(!validTelemetryReading(metric, INFINITY));
  }
  assert(!validTelemetryReading(TelemetryMetric::Temperature, NAN));
  assert(validTelemetryReading(TelemetryMetric::Light, 54.3f));
  assert(!validTelemetryReading(TelemetryMetric::Count, 50));
  TelemetrySchedule schedule(2000);
  schedule.reset(1000, true);
  assert(schedule.due(1000));
  assert(!schedule.due(2999));
  assert(schedule.due(3000));
  assert(!schedule.due(3001));
  // A late iteration must not shift the next sample by the same delay.
  assert(schedule.due(5300));
  assert(!schedule.due(6999));
  assert(schedule.due(7000));
  // A long pause emits only the latest slot, without queued catch-up samples.
  assert(schedule.due(15001));
  assert(!schedule.due(15002));
  assert(schedule.due(17000));
  // Reconnecting starts with an immediate sample and a new two-second phase.
  schedule.reset(19000, true);
  assert(schedule.due(19000));
  assert(!schedule.due(20999));
  assert(schedule.due(21000));
  // millis() rollover must preserve the same cadence.
  schedule.reset(UINT32_MAX - 1000);
  assert(!schedule.due(998));
  assert(schedule.due(999));
  assert(!schedule.due(2998));
  assert(schedule.due(2999));

  // A late DHT22 read must not cause an early read at the next fixed deadline.
  TelemetrySchedule dhtSchedule(2000, 2000);
  dhtSchedule.reset(1000, true);
  assert(dhtSchedule.due(1000));
  assert(dhtSchedule.due(3015));
  assert(!dhtSchedule.due(5000));
  assert(!dhtSchedule.due(5014));
  assert(dhtSchedule.due(5015));
  assert(!dhtSchedule.due(7000));
  assert(dhtSchedule.due(7015));
  // Wi-Fi reconnection cannot bypass the sensor cooldown.
  dhtSchedule.reset(8000, true);
  assert(!dhtSchedule.due(8000));
  assert(dhtSchedule.due(9015));
  assert(!dhtSchedule.due(10000));
  assert(dhtSchedule.due(11015));
  // Both fixed deadlines and read spacing survive unsigned millis() rollover.
  dhtSchedule.reset(UINT32_MAX - 1000, true);
  assert(dhtSchedule.due(UINT32_MAX - 1000));
  assert(!dhtSchedule.due(998));
  assert(dhtSchedule.due(999));
  assert(!dhtSchedule.due(1000));
  TelemetrySchedule disabled(0);
  disabled.reset(0, true);
  assert(!disabled.due(UINT32_MAX));
}
