# ESP32 setup from Flutter

The implemented flow supports the attached EnviroSense Basic v1 sketch on
Android 10 and newer. That sketch implements its own `WebServer` and DNS
portal; it does not include or use tzapu WiFiManager. WiFiManager's captive
portal alone would not provide a stable mobile provisioning API.

## Current protocol

| Operation | ESP32 route | Response |
| --- | --- | --- |
| Identify | `GET /api/device/info` | JSON containing `deviceId`, `deviceType`, `apSsid`, `apIp` |
| Scan (firmware addition) | `GET /api/wifi/networks` | HTTP 202 while scanning; HTTP 200 with network names, RSSI, and security |
| Submit credentials | `POST /save` | Form fields `ssid` and `password`; HTTP 200 HTML acknowledges receipt |
| Confirm Wi-Fi | `GET /api/wifi/status` | JSON containing `connected`, `ssid`, `ip`, `apIp` |

The native Android manager opens each HTTP connection on the `Network`
returned by `WifiNetworkSpecifier`. It never binds the entire process to
the ESP32 network. Android shows the system Wi-Fi consent prompt; it cannot
be bypassed by the app. Cloud SDKs keep using the phone's default network.
See the [Android network request guide](https://developer.android.com/develop/connectivity/wifi/wifi-bootstrap)
and [Network.openConnection](https://developer.android.com/reference/android/net/Network#openConnection(java.net.URL)).

The app reads local identity, releases setup Wi-Fi, checks the existing cloud
registry, and displays the Wi-Fi form. On submission it reconnects and checks
identity again before sending credentials. This also supports phones without
mobile data, provided their regular network has internet access.

During that first local connection the app now attempts an asynchronous ESP32
Wi-Fi scan. The Wi-Fi step offers a signal-sorted network picker, Scan again,
and manual entry for hidden networks. Secured networks require a password;
selecting an open network hides password entry. This needs the
[ESP32 scan header and installation instructions](../firmware/esp32/README.md).
The original sketch has no scan endpoint, so it continues to use manual entry
until that addition is compiled and uploaded. No phone Wi-Fi scanning permissions
are added. Scans come from the ESP32's radio, matching the board's reception.

Releasing the setup network does not guarantee that Android has finished
restoring internet routing. Before registry reads or claiming, the app waits
up to 20 seconds for an internet-capable, validated default network. Verify
shows this recovery step. Transient registry read failures are retried up to
three times, with a six-second timeout per read and bounded delays. If cloud
verification fails, the local identity remains available: restore the phone's
normal Wi-Fi/mobile data and retry Verify without joining the ESP32 again.
Network validation confirms Android's view of internet connectivity; a VPN,
firewall, or Firebase outage can still prevent access to Firestore.

After submission, it polls once a second for up to 30 seconds. Success requires
`connected: true`, the exact submitted SSID, and a nonempty IP other than
`0.0.0.0`. A POST acknowledgement or disappearance of the AP is never success.
The sketch allows a 20-second connection attempt and keeps the AP for only
10 seconds after success, so local confirmation happens before any account
registration work. Short transport interruptions are retried; malformed JSON,
HTTP errors, a changed identity, and explicit failure states are surfaced.

Setup Wi-Fi is released before the existing claim transaction runs. If account
registration fails after confirmed Wi-Fi success, **Retry Registration** retries
only the account step. It does not require the now-closed setup AP. Closing the
page cancels pending connection work and stops polling. A cloud transaction
already submitted may still commit after navigation away.

The app supports the newer identity keys `deviceTypeId`, `serialNumber`, and
`apiVersion` and status keys `status`, `deviceId`, and `ipAddress` when supplied.
For the attached firmware, device name and serial number come from the existing
registry. The firmware's serial number is checked only if it reports one. The
legacy identity is a consistency check, not cryptographic proof of ownership.

## Before using the flow

Use a signed-in account and an existing registered physical device. The existing
registry services expect these documents, created by company/admin tooling:

`deviceTypes/envirosense_basic_v1`:

```json
{
  "deviceTypeId": "envirosense_basic_v1",
  "deviceTypeName": "EnviroSense Basic",
  "status": "active",
  "active": true
}
```

`devices/YEC-DEV-000001`:

```json
{
  "deviceId": "YEC-DEV-000001",
  "deviceName": "EnviroSense Basic",
  "serialNumber": "<actual company-assigned serial number>",
  "deviceTypeId": "envirosense_basic_v1",
  "status": "unclaimed"
}
```

Do not invent the serial number or allow customer apps to create registry
records. The implementation uses the existing database and claim service;
it does not provision or deploy backend resources or rules.

Turn on phone Wi-Fi. Android 13+ requests Nearby Wi-Fi permission; Android
10–12 requests Location permission and requires Location services to discover
the AP. See [Android Wi-Fi permissions](https://developer.android.com/develop/connectivity/wifi/wifi-permissions).
Use a 2.4 GHz router network. Empty passwords are accepted for open networks;
WPA passphrases must be 8–63 ASCII characters, or a 64-character hexadecimal
key. SSIDs retain leading/trailing spaces and are limited to 32 UTF-8 bytes.
Release HTTP access is limited to `192.168.4.1` by the Android
[network security configuration](https://developer.android.com/privacy-and-security/security-config).
Changing the device gateway requires updating both the native manager and XML.

## Firmware changes before production

1. Rotate the Firebase account password exposed in the uploaded sketch.
   Replace the shared Firebase email/password with individually scoped device
   authentication. Provision per-device credentials through trusted tooling;
   each device must be authorized only for its own telemetry path.
2. Assign each board a unique ID, serial, setup SSID, and setup password.
   Put a per-device bootstrap secret or public-key identity in a QR code.
   Verify proof of possession in a backend claim operation; a predictable
   device ID and registry lookup do not establish ownership.
3. Provide a versioned JSON API rather than using `/save` HTML long term.
   Add `GET /api/wifi/networks`, `POST /api/provision/wifi`,
   `GET /api/provision/status`, and a finish acknowledgement. Use an attempt ID,
   explicit states (`connecting`, `connected`, `failed`), and machine-readable
   failure reasons so a client can distinguish a bad password from AP loss.
4. Serialize JSON with a library. The attached `/api/wifi/status` concatenates
   SSIDs without escaping them; names containing quotes, backslashes, or
   control characters currently produce invalid JSON. The app reports this
   error, but firmware must fix it to support those networks reliably.
5. Keep the setup AP open until the app acknowledges success or a bounded
   timeout expires. Defer blocking Firebase authentication/uploads until that
   point. Start setup only when unconfigured or when a physical setup/reset
   button is pressed, instead of reopening it on every boot.
6. Save new credentials only after a successful join; preserve the previous
   working configuration on failure. Secure stored credentials and add a
   physical reset path. Prefer authenticated encrypted provisioning, such as
   [Espressif's provisioning framework](https://developer.espressif.com/blog/2026/05/simple-provisioning/),
   over shared-password HTTP.

The app does not store Wi-Fi passwords in preferences or the backend. They
remain transient while retrying and the password field is cleared after local
confirmation. The ESP32 still persists them in Preferences as its sketch does.

The existing firmware uploads temperature and humidity to RTDB, while the
account registry is in Firestore. The device list now displays claimed records.
Live telemetry subscriptions and verification of fresh device cloud heartbeats
are separate work: setup success currently means confirmed router association
and successful account registration, not verified sensor/cloud health.

## Hardware acceptance checks

- Fresh device: accept the system prompt, enter valid router credentials, see
  local confirmation and account registration, and find the device in the list.
- Wrong password or unavailable SSID: receive a timeout, return to the form,
  and retry. The setup AP should remain available on firmware failure.
- Open network, Unicode SSID, and SSID with leading/trailing spaces: confirm
  the exact name. Test quote/backslash names after fixing firmware JSON escaping.
- Denied permission, Wi-Fi disabled, Location disabled on Android 10–12, AP
  out of range, user cancellation, and unsupported platforms: see clear errors.
- Disable mobile data: verify registry checks and claims work after setup Wi-Fi
  is released and the phone restores its regular internet connection.
- Lose phone internet after Wi-Fi succeeds: restore it and select Retry
  Registration without reprovisioning.
- Two boards nearby: choose the intended board and confirm identity changes
  are rejected before any credentials are sent.
- Already configured board: the sketch closes setup about 10 seconds after
  reconnecting to saved Wi-Fi. Restarting reopens it briefly; a persistent
  physical setup mode requires the firmware change described above.

Run automated protocol tests with
`flutter test --no-pub test/features/device_setup/wifi_provisioning_service_test.dart`.
Native permissions, AP radio channel changes, and portal shutdown timing still
require a physical Android phone and ESP32. No iOS platform project or native
adapter is present in this repository.
