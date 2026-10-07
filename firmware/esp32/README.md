# Ready-made ESP32 Dev Module firmware

The complete sketch is in [`main/main.ino`](main/main.ino). The private ready-made archive is `yening_esp32_ready.zip`.

The sketch includes asynchronous Wi-Fi scanning, the Flutter provisioning endpoints, a browser setup portal, DHT22 readings on GPIO 4, analog LDR readings on GPIO 34, saved Wi-Fi reconnection, and Firebase Realtime Database telemetry. It retains the working device identity and private Firebase configuration.

## Included files

- `main.ino`: complete application, provisioning state, sensor readings, and cloud uploads.
- `device_config.h`: device identity, GPIOs, and connection timing.
- `light_sensor.h`: bounded, calibrated relative-light conversion.
- `telemetry_schedule.h`: fixed sampling cadence, rollover handling, and sensor snapshot structure.
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

Credentials are persisted only after the device connects to the requested network and obtains an IP address. A failed attempt keeps setup available. Firebase authentication starts after the setup portal closes, keeping local setup requests responsive. Holding the BOOT button for five seconds clears saved Wi-Fi. Telemetry remains at `/deviceLive/YEC-DEV-000001` with connectivity and temperature/humidity/light fields.

## Light sensor

The confirmed analog input is GPIO34 (ADC1). The firmware configures a 12-bit ADC, averages 16 samples, and sends `telemetry/light` as a relative brightness percentage with one decimal place. GPIO34's ADC1 channel remains available while Wi-Fi is active. See [Espressif ADC documentation](https://docs.espressif.com/projects/esp-idf/en/v4.4.3/esp32/api-reference/peripherals/adc.html) and the [Arduino ADC API](https://docs.espressif.com/projects/arduino-esp32/en/latest/api/adc.html).

The conversion now follows the requested falling-voltage direction: ADC 4095 maps to dark (0%) and ADC 0 maps to bright (100%). The exact sensor hardware and measured calibration endpoints have not been confirmed. Analog module AO can connect to GPIO34 with a common ground and a signal within the ESP32's 3.3 V input limit; its polarity depends on the module circuit.

`LDR_DARK_ADC` and `LDR_BRIGHT_ADC` in `device_config.h` are the two reference readings. They can use measured dark/bright endpoints and can be reversed for a circuit whose output falls in brighter light. Serial uploads include the averaged raw ADC value for calibration. Endpoints are initial full-scale references, not measured calibration. The result is a relative sensor level, not calibrated lux or a physically linear illuminance percentage. A bare LDR requires its divider resistor; an unconnected analog input cannot provide a valid light measurement.

Light uploads continue if the DHT22 is unavailable. Invalid temperature/humidity fields are removed so the current heartbeat does not make old DHT samples appear fresh. Flutter shows missing readings as dashes and retains the live light gauge.

Home and Device Details show a light condition below the percentage: **Dark** for 0–5%, **Low light** for greater than 5% through 20%, and **Bright** for greater than 20% through 100%. Missing or invalid light readings have no condition label. The label is included in the gauge's accessibility description.

## Firebase diagnostics

Serial output reports both the Firebase authentication error code and server message, with configured credentials redacted. `Firebase client initialized` means configuration is ready; `Firebase authentication ready` confirms a usable token. Database upload failures report their code and reason separately.

The sketch uses the earlier Firebase ESP Client SDK flow: `firebaseAuth.user.email`, `firebaseAuth.user.password`, and `Firebase.begin()`. The SDK manages sign-in and token refresh. The separate REST authentication, retry-policy, and root-certificate files have been removed from the sketch and archive. Empty device credentials prevent authentication attempts and produce a clear serial message.

The device account identifier is `device-yec-dev-000001@yeninginnovation.com`. It belongs in this project's Firebase Authentication with the Email/Password provider; the Google account managing Firebase Console is a separate identity. The password belongs only in private `firebase_secrets.h`, and the resulting Authentication UID belongs in RTDB at `deviceAccess/YEC-DEV-000001/writerUid`. The app owner's UID remains `LfyDXygCVocPj51mja8D8JvvMUG3`. Each device has a separate writer identity. The current rules require it to differ from the owner's identity.

This direct device-to-RTDB development flow works on Firebase Spark within its no-cost limits and requires no Cloud Functions. The database URL, device ID, telemetry field names, and server timestamp match the Flutter realtime telemetry service. Uploads contain measured temperature in Celsius, humidity in percent, and relative light in percent every five seconds while connected. The existing RTDB rules already permit light percentages from 0 through 100; no import or schema migration is needed to add live light readings.

## Five-second sampling and uploads

Once provisioning finishes and Wi-Fi is connected, the sensor loop captures temperature, humidity, and light together immediately and then on a fixed 5,000 ms schedule. Temperature forces a fresh DHT22 frame and humidity uses that same frame. The schedule retains its phase when a loop iteration runs late and skips missed slots without producing an upload burst. A separate FreeRTOS worker exclusively owns the Firebase SDK, authentication, token refresh, and database uploads. Its network calls cannot block the sensor/provisioning loop. The single-slot queue keeps the latest snapshot during a slow request; old snapshots are discarded after five seconds.

The uploader sends one confirmed, atomic PATCH containing all three readings and the shared `connectivity/lastSeen` server timestamp. `FIREBASE_LOG_SERVER_TIMING` is enabled for development: `updateNode()` returns the small JSON response with the resolved server timestamp from that exact write. The firmware prints that timestamp and the interval since the previous server timestamp. This requires no extra GET or write. With this flag disabled, `updateNodeSilent()` omits the echoed JSON response and still waits for confirmation. Reusing the Firebase data object retains HTTP keep-alive; TCP keep-alive probes are also enabled. SDK retries are disabled so failed readings cannot build a backlog. The actual TLS client's handshake timeout is three seconds (`config.timeout.sslHandshake` is unused in SDK 4.4.17), and the server-response timeout is two seconds. These are stage-specific limits, not an overall network-delivery deadline. Station Wi-Fi power saving is disabled to reduce latency on the Dev Module.

Under normal connectivity, each sample uploads all three fields and a server heartbeat in one RTDB update. Serial messages distinguish sample capture, sample age at upload, request duration, the interval between confirmed uploads, and the interval between server timestamps. These are separate measurements: capture time alone does not prove when Firebase receives the readings. The startup marker `atomic-5s-server-timing-v3` identifies this build. Network outages, slow authentication, and request failures can still delay cloud delivery; the app does not invent replacement readings to simulate a successful five-second upload. The current realtime listener receives each RTDB change immediately, even if measured values are unchanged, because the heartbeat changes. The panel displays the last server update in local time including seconds, alongside relative freshness. Its freshness display also refreshes every five seconds. See [Firebase realtime listeners and atomic updates](https://firebase.google.com/docs/database/flutter/read-and-write), [REST writes and server timestamps](https://firebase.google.com/docs/database/rest/save-data), and [ESP32 FreeRTOS queues/tasks](https://docs.espressif.com/projects/esp-idf/en/v4.3/esp32/api-reference/system/freertos.html).

The user's supplied serial trace captures samples every 5,000 ms (with occasional 1 ms loop jitter), each followed by a successful upload. Temperature stays at 28.5 C throughout, humidity varies only between 62.3% and 62.4%, and ADC remains at 4095. Unchanged sensor values do not need to visibly change each interval; `lastSeen` identifies each new update. If the ADC remains at 4095 under both bright and dark conditions, changing the conversion direction alone cannot provide variable light readings; wiring and sensor calibration need checking.

A read-only observation of the running device's live RTDB stream on October 7, 2026 received six new server heartbeats. Consecutive `lastSeen` gaps were **4,985, 5,005, 4,995, 4,999, and 5,020 ms** (average 5,000.8 ms). During that observation the database was receiving updates every five seconds. The reported Console delay therefore appears to be in the display of those observed updates. This is a limited observation of the existing running firmware; it does not rule out intermittent delivery problems at other times or verify the newly compiled diagnostic firmware on the physical board. Database contents and rules were not changed by this observation.

Home subscribes only to the selected device. With at least two owned devices, a pinned switch button opens the device selection sheet; selecting another device cancels the old telemetry listener. Device removal selects a remaining device, while loading/account changes clear previous readings. Add Device exists only on Devices as a floating action button, above the lazily built device list.

## Validation

The automatic dependency profile specifies Arduino-ESP32 2.0.17, Firebase ESP Client 4.4.17, DHT sensor library 1.4.6, and Adafruit Unified Sensor 1.1.15 for `esp32:esp32:esp32`.

The private ZIP contains exactly the eight sketch files listed above and matches their contents.

The updated diagnostic profile build passed using 1,122,457 bytes of flash (85%) and 49,072 bytes of static RAM (14%). The upload task also allocates a 16 KiB stack from the heap. The unchanged Flutter UI previously passed all 73 device/setup tests and static analysis. The 77 local RTDB checks cover confirmed PATCH responses with resolved server timestamps, silent PATCH writes, rejection of an entire snapshot when one reading is invalid, and authorization isolation.

Host checks covered the scan state, JSON encoding, supported security flags, empty/failure results, and the result limit. Browser checks covered automatic scan polling, form encoding, matching the requested SSID, clearing the password field, and resetting Wi-Fi.

RTDB authorization tests cover the firmware upload format, owner-only app access, isolated writers, and first-upload creation without a placeholder live record. Flutter tests cover streamed updates, gauges, temperature unit conversion, connection status, and listener cleanup.

Host conversion checks cover both divider directions, calibrated endpoints, clamping, rounding, and invalid reference values. Flutter tests cover live light on Home and Device Details, missing/zero light readings, large text, retained values during disconnects, and continued light updates when DHT readings disappear. RTDB tests cover the full three-sensor upload and clearing unavailable DHT fields.

Host scheduling checks cover five-second deadlines, late iterations, missed intervals, immediate reconnect sampling, and `millis()` rollover. Widget checks cover device switching, listener cleanup, selection retention after registry reordering, removal fallback, empty Home without Add Device, and the persistent floating action while scrolling many devices.

Flutter checks also cover exact light-label boundaries, accessibility labels, clearing the label for missing readings, and visible five-second timestamp changes while all measured values remain unchanged. Physical LDR wiring, calibration, and end-to-end delivery timing have not been verified with the updated firmware.
