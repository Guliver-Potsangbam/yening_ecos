#include <cassert>
#include <stdint.h>

#include "../main/telemetry_schedule.h"

int main() {
  TelemetrySchedule schedule(5000);
  schedule.reset(1000, true);
  assert(schedule.due(1000));
  assert(!schedule.due(5999));
  assert(schedule.due(6000));
  assert(!schedule.due(6001));
  // A late iteration must not shift the next sample by the same delay.
  assert(schedule.due(11300));
  assert(!schedule.due(15999));
  assert(schedule.due(16000));
  // A long pause emits only the latest slot, without queued catch-up samples.
  assert(schedule.due(36001));
  assert(!schedule.due(36002));
  assert(schedule.due(41000));
  // Reconnecting starts with an immediate sample and a new five-second phase.
  schedule.reset(43000, true);
  assert(schedule.due(43000));
  assert(!schedule.due(47999));
  assert(schedule.due(48000));
  // millis() rollover must preserve the same cadence.
  schedule.reset(UINT32_MAX - 2000);
  assert(!schedule.due(2998));
  assert(schedule.due(2999));
  assert(!schedule.due(7998));
  assert(schedule.due(7999));
}
