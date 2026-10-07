# Monitoring UI review

The monitoring experience now gives temperature, humidity, and light equal visual weight, while separating a device's connection from each sensor's data freshness. The update focuses on Home, Device Details, Devices, and the shared application theme/navigation.

## Findings and changes

| Finding | Result |
| --- | --- |
| Temperature occupied a larger card than the other metrics. | Every sensor reserves matching heading, dial, status, and timestamp space. Compact rows fit phones; three equal columns fit larger screens. |
| A shared update time could make an older sensor appear current. | Each card displays its own server `updatedAt` and Live/Stale/Waiting/Offline state. “Device seen” sits with connection status above the gauges and refers only to the device heartbeat. |
| Large numeric values competed with the instrument dial. | Values use a smaller 20 px base size with tabular figures, while retaining the exact value in accessibility semantics. |
| Times used a 24-hour clock without individual sensor context. | UTC timestamps convert to the phone's local timezone and show seconds plus AM/PM. A tooltip includes the local date. |
| Solid page backgrounds and nested cards weakened the content hierarchy. | Soft teal/slate gradients frame solid instrument cards. Device identity is a separate summary, followed by readings. |
| Compact temperature controls had undersized touch areas. | The C/F selector remains local to Temperature and passes Android's 48 px touch-target guideline. |
| Large fonts and fallback fonts could change card heights. | Common reserved slots retain equal dimensions and allow vertical scrolling, including 320 px screens at 2× text size. |
| Add Device could compete with monitoring. | It remains a persistent action on Devices; Home keeps its device-switch sheet. |
| Device Details repeated the readings without explaining the hardware. | Live Firestore device and model documents supply customer-visible setup, firmware, hardware, measurement/control capability, and lifecycle sections. Secondary details expand on demand. |

The visual direction uses restrained color, a readable type hierarchy, tabular sensor values, and analog needles with magnitude bands. Magnitude bands describe low/medium/high readings rather than clinical or alarm limits. Freshness also uses text and icons, so color is not its only signal. Light retains the app's existing 23%/45% condition boundaries.

The light and dark themes follow system appearance. Gradient decoration stays behind solid surfaces, preserving readable labels and instrument faces. This follows [Material color-role guidance](https://m3.material.io/styles/color/the-color-system) and [Flutter's accessibility guidance](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling). The existing reduced-motion setting continues to disable needle animation.

## Data behavior

Each sensor uses `deviceLive/<deviceId>/telemetry/<metric>/{value, updatedAt}`. Independent writes replace one complete value/timestamp record without replacing sibling metrics. Reading values stay in canonical Celsius or percent; switching C/F changes presentation only.

Legacy numeric records remain readable during rollout. Once independent records appear, scalar siblings keep their values but receive no inferred time from another sensor's heartbeat; their timestamp remains unknown until they upload their own record. Missing or malformed pairs remain unavailable. Device and sensor freshness use their respective timestamps.

Two seconds is the sampling target. Network requests are serialized by the firmware's Firebase worker, so sensor server timestamps can differ by request duration. DHT22 temperature and humidity share one physical sensor frame; their cloud records and update times are independent. The 30-second task watchdog remains enabled.

Device Details reads the existing `devices/<deviceId>` and `deviceTypes/<deviceTypeId>` documents. This information remains independent of the RTDB subscription: missing model data or a failed metadata lookup does not hide live readings. Only known customer-visible fields are presented; ownership/authentication identifiers and arbitrary document properties are excluded. Unrecorded fields and schema placeholders do not become invented hardware details. Device identifiers are available for support, while dates use the same local AM/PM formatter as the readings.

## Validation and rollout

All 116 Flutter tests pass, and full-project static analysis reports no issues. Widget checks cover independent updates, unchanged values with advancing timestamps, stale-sensor isolation, local noon/midnight formatting, equal card dimensions, temperature-only controls, touch targets, and narrow/light/dark/tablet/large-text layouts. Metadata checks cover allowlisted fields, malformed optional data, missing model documents, account/ownership/type changes, subscription cleanup, and device/retry loading frames that clear prior metadata while preserving live readings. Actual-widget previews are generated in `build/telemetry_previews/`, including the expanded device-information view.

The firmware and private ready-made archive have been rebuilt. RTDB rules pass 151 local emulator checks. Publishing the updated [`database.rules.json`](../database/database.rules.json) is required before the new firmware writes object records; this work has not published cloud rules or replaced live data. The [terminal deployment commands](../database/README.md#publish-rtdb-rules-from-the-terminal) use the existing project configuration and publish only RTDB rules. Physical timing and watchdog recovery remain unverified on the board.
