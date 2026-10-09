# Ready-made ESP32 Dev Module firmware

The complete sketch is in [`main/main.ino`](main/main.ino). The private ready-made archive is `yening_esp32_ready.zip`.

The sketch includes asynchronous Wi-Fi scanning, the Flutter provisioning endpoints, a browser setup portal, DHT22 readings on GPIO 4, analog LDR readings on GPIO 34, saved Wi-Fi reconnection, and independent Firebase Realtime Database sensor records on a two-second schedule. A task watchdog monitors both the sensor/setup loop and the Firebase uploader. It retains the working device identity and private Firebase configuration.

## Included files

- `main.ino`: complete application, provisioning state, sensor readings, and cloud uploads.
- `device_config.h`: device identity, GPIOs, and connection timing.
- `light_sensor.h`: bounded, calibrated relative-light conversion.
- `telemetry_schedule.h`: fixed sampling cadence, rollover handling, independent metric readings, and validity checks.
- `task_watchdog.h`: watchdog configuration and current-task registration for the IDF 4/5 APIs.
- `wifi_scan_api.h`: asynchronous nearby-network scan endpoint and JSON escaping.
- `portal_ui.h`: browser setup interface with the same scan and provisioning API.
- `firebase_secrets.h`: supplied private Firebase configuration; excluded from Git.
- `sketch.yaml`: ESP32 board and library versions for a reproducible build.

## Flutter API

| Endpoint | Response |
| --- | --- |
| `GET /api/device/info` | Device identity and setup state. |
| `GET /api/wifi/networks` | HTTP 202 while scanning, HTTP 200 with nearby networks. |
| `POST /save` | Form-encoded SSID and password; HTTP 202 queues a connection. |
| `GET /api/wifi/status` | Connection state, target SSID, station IP, and failure code. |

Credentials are persisted only after the device connects to the requested network and obtains an IP address. A failed attempt keeps setup available. Firebase authentication starts after the setup portal closes, keeping local setup requests responsive. Holding the BOOT button for five seconds while running reopens setup for five minutes without clearing saved Wi-Fi. Failed replacement credentials never overwrite the saved pair; after the app can observe the failure for ten seconds, the firmware attempts the previous network. An offline device automatically reopens setup after its existing reconnection timeout. Erased NVS settings also reopen setup on boot. Cloud ownership remains in Firestore and is unaffected by clearing local Wi-Fi settings. Telemetry remains at `/deviceLive/YEC-DEV-000001` with connectivity and temperature/humidity/light fields.

## Light sensor

The confirmed analog input is GPIO34 (ADC1). The firmware configures a 12-bit ADC, averages 16 samples, and sends `telemetry/light/value` as a relative brightness percentage with one decimal place, paired with its own server `updatedAt`. GPIO34's ADC1 channel remains available while Wi-Fi is active. See [Espressif ADC documentation](https://docs.espressif.com/projects/esp-idf/en/v4.4.3/esp32/api-reference/peripherals/adc.html) and the [Arduino ADC API](https://docs.espressif.com/projects/arduino-esp32/en/latest/api/adc.html).

The conversion now follows the requested falling-voltage direction: ADC 4095 maps to dark (0%) and ADC 0 maps to bright (100%). The exact sensor hardware and measured calibration endpoints have not been confirmed. Analog module AO can connect to GPIO34 with a common ground and a signal within the ESP32's 3.3 V input limit; its polarity depends on the module circuit.

`LDR_DARK_ADC` and `LDR_BRIGHT_ADC` in `device_config.h` are the two reference readings. They can use measured dark/bright endpoints and can be reversed for a circuit whose output falls in brighter light. Serial uploads include the averaged raw ADC value for calibration. Endpoints are initial full-scale references, not measured calibration. The result is a relative sensor level, not calibrated lux or a physically linear illuminance percentage. A bare LDR requires its divider resistor; an unconnected analog input cannot provide a valid light measurement.

Light uploads continue if the DHT22 is unavailable. An invalid temperature/humidity reading removes only its own value/timestamp record; healthy metrics continue independently. Flutter shows missing readings as dashes and retains the live light gauge.

Home and Device Details show each sensor's own local last-update time and freshness. Light condition labels use the app's configured thresholds. A device heartbeat never supplies the timestamp for a new-format sensor reading.

## Firebase diagnostics

Serial output reports both the Firebase authentication error code and server message, with configured credentials redacted. `Firebase client initialized` means configuration is ready; `Firebase authentication ready` confirms a usable token. Database upload failures report their code and reason separately.

The sketch uses the earlier Firebase ESP Client SDK flow: `firebaseAuth.user.email`, `firebaseAuth.user.password`, and `Firebase.begin()`. The SDK manages sign-in and token refresh. The separate REST authentication, retry-policy, and root-certificate files have been removed from the sketch and archive. Empty device credentials prevent authentication attempts and produce a clear serial message.

The device account identifier is `device-yec-dev-000001@yeninginnovation.com`. It belongs in this project's Firebase Authentication with the Email/Password provider; the Google account managing Firebase Console is a separate identity. The password belongs only in private `firebase_secrets.h`, and the resulting Authentication UID belongs in RTDB at `deviceAccess/YEC-DEV-000001/writerUid`. The app owner's UID remains `LfyDXygCVocPj51mja8D8JvvMUG3`. Each device has a separate writer identity. The current rules require it to differ from the owner's identity.

This direct device-to-RTDB development flow works on Firebase Spark within its no-cost limits and requires no Cloud Functions. The database URL, device ID, telemetry field names, and server timestamp match the Flutter realtime telemetry service. Uploads contain measured temperature in Celsius, humidity in percent, and relative light in percent on a two-second schedule while connected. The bundled RTDB rules validate the new sensor record format and retain temporary numeric-reading compatibility for an incremental rollout. The live database needs those updated rules before the new firmware writes record objects; the local changes have not been published to Firebase. Importing initial data again is unnecessary.

## Independent two-second sensor records

Each metric is stored as `{ "value": <number>, "updatedAt": <server timestamp in milliseconds> }` at `deviceLive/<deviceId>/telemetry/<metric>`. Temperature remains Celsius; humidity and relative light remain percentages. Units and metadata stay in Firestore.

The DHT22 schedule captures one fresh hardware frame every 2,000 ms or later. Temperature and humidity share that physical frame but have separate latest-value queues and separate Firebase writes. A separate two-second light schedule averages the LDR readings and queues only light. The DHT scheduler guards the sensor's two-second cooldown even after a late iteration or rapid reconnect. The minimum interval is enforced at compile time. See the [DHT library's minimum read interval](https://github.com/adafruit/DHT-sensor-library/blob/1.4.6/DHT.cpp).

A FreeRTOS worker exclusively owns the Firebase SDK, authentication, token refresh, and uploads. Three one-slot queues retain the latest reading per metric without building a backlog. Samples older than two seconds are skipped; a slow or failed metric request does not make the next metric wait for a retry. Network calls cannot block the sensor/provisioning loop.

Each confirmed, multi-location PATCH contains one entire metric record plus `connectivity/isOnline` and the `connectivity/lastSeen` server heartbeat. `FirebaseJson.add()` creates literal slash-separated keys: the metric's value and `updatedAt` commit atomically while the sibling metrics and their timestamps stay intact. Invalid readings delete that entire metric record, preserving healthy siblings. The device heartbeat reflects the latest confirmed request, while sensor freshness uses only that sensor's `updatedAt`. No old value receives a fresh sensor timestamp.

All three metrics target a two-second capture/upload cadence. The single SDK-owner worker serializes the three requests, so their server timestamps can differ by request latency. Sampling does not wait for cloud delivery, and a missing DHT reading cannot prevent light capture. Exact two-second cloud arrivals are not guaranteed during network latency, outages, authentication, or slow requests.

`FIREBASE_LOG_SERVER_TIMING` is enabled for development. The normal confirmed PATCH response contains the resolved server timestamps; the firmware prints each metric's `updatedAt`, its interval since the preceding confirmed metric timestamp, the capture time, sample age, and request duration. Repeated values still get a new `updatedAt`. The response parser supports RTDB's nested response and a literal-key echo. Diagnostics require no extra GET or write. Disabling this flag uses `updateNodeSilent()` while retaining server confirmation.

The startup marker is `independent-metrics-2s-watchdog-v5`. SDK retries remain disabled, the Firebase data object keeps HTTP/TCP keep-alive, the actual TLS handshake timeout is three seconds, and server response timeout is two seconds. These limits apply to individual network stages; the task watchdog remains the recovery mechanism for a network call that stops returning.

Flutter listens to the full device node, preserving a coherent local view when any independent metric changes. The updated app reads the new record format and retains old numeric readings during firmware rollout. In a mixed-format record, legacy scalar values remain visible but get no timestamp inferred from another sensor's heartbeat; each waits for its own complete record. Sensor cards display their own local 12-hour update times rather than borrowing the device heartbeat. Home subscribes only to the selected device; switching devices cancels the old listener. Add Device remains on Devices.

The supplied earlier timing trace verifies the preceding five-second build. Current validation covers local emulator delivery and the compiled independent two-second firmware. Physical timing remains to be measured after flashing this build.

## Watchdog recovery

`TASK_WATCHDOG_TIMEOUT_SECONDS` is 30 seconds. It is a task-stall recovery limit, separate from the two-second telemetry cadence. The sensor/setup task and `firebase-upload` task each register their own subscription and feed it when their loop makes progress. The uploader continues feeding during ordinary offline waits, missing-credential waits, and authentication retry iterations. A network call that stops returning, or a sensor/setup loop that hangs, cannot be hidden by the other task continuing to run.

The watchdog enables panic on timeout. The pinned ESP32 core uses the panic-and-reboot configuration, so a stalled task triggers device recovery and saved Wi-Fi is restored through the existing startup flow. Startup logs identify both subscriptions, initialization failures, and a previous watchdog restart. Configuring the watchdog retains the SDK's idle-task monitoring; the core's interrupt watchdog remains active. The compatibility adapter handles Arduino-ESP32 2.x/IDF 4 and 3.x/IDF 5 initialization signatures, but the full firmware build is validated against the pinned 2.0.17 profile. See the [IDF 4 watchdog API](https://docs.espressif.com/projects/esp-idf/en/v4.4.7/esp32/api-reference/system/wdts.html) and [IDF 5 watchdog API](https://docs.espressif.com/projects/esp-idf/en/v5.1.4/esp32/api-reference/system/wdts.html).

## Validation

The automatic dependency profile specifies Arduino-ESP32 2.0.17, Firebase ESP Client 4.4.17, DHT sensor library 1.4.6, and Adafruit Unified Sensor 1.1.15 for `esp32:esp32:esp32`.

The private ZIP contains exactly the nine sketch files listed above and matches their contents.

The updated profile build passed using 1,125,213 bytes of flash (85%) and 49,128 bytes of static RAM (14%). The upload task also allocates a 16 KiB stack from the heap. All 151 local RTDB authorization checks pass and validate separate value/timestamp pairs, repeated values with advancing individual timestamps, sibling preservation, malformed records, isolated failures, invalid-sensor clearing, owner/writer isolation, and compatibility with the earlier numeric schema. The realtime stream checks use owner credentials and two-second test intervals.

Host checks cover both light divider directions, calibrated endpoints, clamping, rounding, invalid references, per-metric value bounds, two-second deadlines, late iterations, missed intervals, DHT cooldown, reconnect behavior, and `millis()` rollover. Watchdog adapter checks compile against simulated IDF 4 and IDF 5 APIs and verify timeout units, panic configuration, idle-task settings, duplicate subscription avoidance, reconfiguration, and API errors. They do not emulate the hardware watchdog or verify an actual ESP32 restart.

All 154 Flutter tests pass, including independent sensor timestamps, mixed-format migration, unchanged value updates, per-sensor freshness, local AM/PM noon/midnight display, equal-sized cards, 48 px temperature controls, dark mode, large text, device switching, provisioning, and actual app startup. The [monitoring UI review](../../docs/monitoring_ui_review.md) records the visual and interaction changes.

The firmware's physical LDR calibration, end-to-end delivery timing, and watchdog recovery have not been tested on the updated board. No live Firebase data, access mapping, Authentication account, or cloud rules were changed by these local checks.

The Wi-Fi reconnect flow and Firestore provisioning writes are described in [device setup](../../docs/device_setup.md#confirmed-provisioning-and-changing-wi-fi). Local checks additionally validate recovery state transitions and 24 Firestore setup-rule cases. The archive includes the updated non-destructive BOOT/setup action and rollback behavior.
