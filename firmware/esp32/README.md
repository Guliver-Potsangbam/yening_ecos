# Ready-made ESP32 Dev Module firmware

The complete sketch is in [`main/main.ino`](main/main.ino). The private ready-made archive is `yening_esp32_ready.zip`.

The sketch includes asynchronous Wi-Fi scanning, the Flutter provisioning endpoints, a browser setup portal, DHT22 readings on GPIO 4, saved Wi-Fi reconnection, and Firebase Realtime Database telemetry. It retains the device identity and Firebase configuration from the supplied sketch.

## Included files

- `main.ino`: complete application, provisioning state, sensor readings, and cloud uploads.
- `device_config.h`: device identity, GPIOs, and connection timing.
- `wifi_scan_api.h`: asynchronous nearby-network scan endpoint and JSON escaping.
- `portal_ui.h`: browser setup interface with the same scan and provisioning API.
- `firebase_secrets.h`: supplied private Firebase configuration; excluded from Git.
- `firebase_auth_client.h`: one verified HTTPS request per sign-in or token refresh.
- `firebase_auth_retry.h`: authentication cooldowns and account-configuration failure handling.
- `google_root_certificates.h`: public Google Trust Services root certificates for HTTPS verification.
- `sketch.yaml`: ESP32 board and library versions for a reproducible build.

## Flutter API

| Endpoint | Response |
| --- | --- |
| `GET /api/device/info` | Device identity and setup state. |
| `GET /api/wifi/networks` | HTTP 202 while scanning, HTTP 200 with nearby networks. |
| `POST /save` | Form-encoded SSID and password; HTTP 202 queues a connection. |
| `GET /api/wifi/status` | Connection state, target SSID, station IP, and failure code. |

Credentials are persisted only after the device connects to the requested network and obtains an IP address. A failed attempt keeps setup available. Firebase authentication starts after the setup portal closes, keeping local setup requests responsive. Holding the BOOT button for five seconds clears saved Wi-Fi. Telemetry remains at `/deviceLive/YEC-DEV-000001` with the original connectivity and temperature/humidity fields.

## Firebase diagnostics

Serial output reports both the Firebase authentication error code and server message, with configured credentials redacted. `Firebase sign-in configured` means configuration is ready; `Firebase authentication ready` confirms a usable token. Database upload failures report their code and reason separately. The sketch uses a Firebase Authentication email/password account in the configured project. Google sign-in credentials and passkeys belong to a separate sign-in flow; the sketch does not implement a second-factor challenge.

Password sign-in and token refresh use the official Firebase REST endpoints with verified HTTPS and connection/read timeouts. The Firebase ESP Client SDK receives only an already validated ID token, keeping its blocking password retry loop out of the application. Time synchronizes before HTTPS, and token renewal starts two minutes before expiry. Refresh tokens stay in RAM and are never printed.

`TOO_MANY_ATTEMPTS_TRY_LATER` or HTTP 429 pauses authentication for 15 minutes, increasing to 30 minutes and then at most one hour after repeated throttling. Other transient failures back off from 30 seconds to five minutes. Duplicate callbacks cannot shorten the cooldown. Known invalid credentials, disabled accounts/providers, invalid API keys, and MFA requirements stop retries until configuration is corrected and the device restarts. These local cooldowns do not remove a Firebase block or guarantee its expiry; rebooting resets local retry state.

## Validation

Compiled successfully for `esp32:esp32:esp32` using Arduino-ESP32 2.0.17, Firebase ESP Client 4.4.17, DHT sensor library 1.4.6, and Adafruit Unified Sensor 1.1.15. Both the standard build and the packaged automatic dependency profile passed for the initial bundle. The latest authentication change passed the profile build and fits the default flash partition and static RAM limits.

Host checks covered the scan state, JSON encoding, supported security flags, empty/failure results, and the result limit. Browser checks covered automatic scan polling, form encoding, matching the requested SSID, clearing the password field, and resetting Wi-Fi.

`tests/firebase_auth_retry_test.cpp` covers throttling, increasing and capped waits, duplicate error reports, upgrades from a short pause to a throttle pause, successful recovery, timer wrapping, and stopping retries for invalid credentials or MFA requirements.

Physical ESP32, radio, DHT22, and live Firebase operation have not been tested with this replacement firmware.
