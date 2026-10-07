# Minimal EnviroSense RTDB contract

[`rtdb.import.json`](rtdb.import.json) is the initial import for `YEC-DEV-000001`, owned by Firebase Authentication UID `LfyDXygCVocPj51mja8D8JvvMUG3` (`test@example.com`, supplied by the owner). It contains two branches: `deviceLive` for runtime data and `deviceAccess` for authorization. Importing at the database root replaces data at that location; this file initializes a database rather than migrating existing readings.

Firestore holds the `devices`, `deviceTypes`, and `users` collections. Device names, serial numbers, types, firmware versions, claim/provisioning status, hardware descriptions, telemetry definitions, supported units, and control definitions stay there. RTDB holds no duplicate metadata, account emails, passwords, or tokens.

## Live data

| Path under `deviceLive/<deviceId>` | Stored value |
| --- | --- |
| `telemetry/temperature/value` | Numeric Celsius, -40 to 80 |
| `telemetry/humidity/value` | Numeric relative humidity percent, 0 to 100 |
| `telemetry/light/value` | Numeric relative light percent, 0 to 100 |
| `telemetry/<metric>/updatedAt` | That metric's Firebase server timestamp, Unix milliseconds |
| `connectivity/lastSeen` | Firebase server timestamp in Unix milliseconds |
| `connectivity/isOnline` | Boolean reported by the device |

`light` matches the supplied Firestore device-type definition. The firmware samples the LDR on confirmed GPIO34, averages 16 readings, and normalizes them to a bounded relative percentage using the dark/bright reference values in `device_config.h`. The current endpoints map ADC 4095 to 0% and ADC 0 to 100%; measured calibration remains to be confirmed. The contract accepts decimal percentages; it does not label raw ADC counts as percent or lux. Flutter displays a third live light gauge on Home and Device Details. A DHT22 failure does not stop light uploads; unavailable DHT fields are cleared rather than shown as fresh values.

Each sensor record contains only `value` and `updatedAt`. Firmware captures each metric on a two-second schedule and sends three separate writes. Temperature and humidity come from one DHT22 hardware frame, then upload independently. Light has its own schedule and queue. Each metric's value/server timestamp pair is atomic, and the same request advances the device connectivity heartbeat. A malformed or failed metric write does not prevent attempts to upload the others. Sibling values and timestamps stay intact, and unchanged readings still receive a new individual `updatedAt`.

The shared Firebase worker serializes network calls, so the three sensor timestamps can differ by request latency. Two seconds is the capture/delivery target, not a guarantee of exact cloud arrival during network or authentication delays. A missing sensor record means unavailable data; the firmware removes only that invalid metric rather than marking an old value fresh. Flutter displays each metric's own local 12-hour update time and freshness separately from the device heartbeat.

The bundled rules require numeric, in-range values and positive integer timestamps. They reject missing record members, unknown children, invalid/future/old timestamps, timestamp regressions, and value changes that retain the old timestamp. Unchanged sibling records remain valid during another sensor's write. Legacy numeric metrics remain temporarily valid for a rolling firmware migration; those records have no independent timestamp.

The app can use the shared heartbeat as the timestamp of an entirely legacy numeric snapshot. Once any independent object record appears, scalar siblings keep their values but have no inferred timestamp. They remain waiting until their own value/time record arrives, so a light update cannot make an unmigrated temperature or humidity reading appear fresh.

Publish the updated [`database.rules.json`](database.rules.json) before the new firmware uploads record objects. The old numeric-only cloud rules reject the new format. This repository update and emulator validation have not published cloud rules. Existing live records migrate automatically as each metric first uploads; reimporting `rtdb.import.json` would overwrite existing data and is unnecessary.

The import shows each metric as `{ "value": null, "updatedAt": null }`, matching the independent record format without inventing measurements or update times. RTDB removes null values and empty objects, so these placeholder records and the telemetry branch appear in Firebase only when the device uploads real value/timestamp pairs. Zero remains a valid measurement. `isOnline: false` and `lastSeen: 0` indicate that no heartbeat has been recorded in this seed. Claimed/provisioned status remains in Firestore; it does not prove that a fresh cloud heartbeat exists. The app already checks heartbeat freshness against a 60-second threshold and converts Celsius to Fahrenheit for display.

## Access

The import grants the supplied owner UID read access when paired with [`database.rules.json`](database.rules.json). Those rules belong in the RTDB Rules configuration rather than in imported data. The owner cannot edit access mappings or upload sensor values.

`writerUid` is `uHGaJO8R4GNha8yYTLOh2flUS7C3`, the Firebase Authentication UID of the dedicated device account `device-yec-dev-000001@yeninginnovation.com`. That account has been created in the development project. Its generated password is stored only in the private firmware configuration and private ready-made ZIP, not in RTDB or Firestore. The firmware now uses this device account rather than the console administrator's credentials. Only that writer can update its device's telemetry and connectivity; using the owner UID as the writer is rejected. An administrator manages this mapping during development; a trusted backend can automate it later.

Each app user can own zero or more devices. Multiple access mappings can reference the same owner UID while each device has a distinct writer UID. Flutter continues to list devices through the existing Firestore `claimedByUid` query and subscribes to individual RTDB live records. The Firestore claim transaction does not currently update RTDB access mappings: an administrator must mirror confirmed ownership, transfers, and revocations during development, or a trusted backend must automate that work later. Normal clients cannot self-assign ownership or list all telemetry.

## Zero-cost development on Spark

Keep the Firebase project on Spark without linking a billing account. Email/password Authentication, Firestore, and RTDB support this development flow within their no-cost quotas. Deployed Cloud Functions require Blaze and are not part of this setup. RTDB's Spark limits are 100 simultaneous connections, 1 GB stored, and 10 GB downloaded per month. Quota exhaustion can interrupt service; Spark does not bill for RTDB usage.

For the already-claimed `YEC-DEV-000001`, the import already assigns the supplied app account as owner. Access can be preassigned for a controlled test device, before provisioning, or assigned by an administrator after confirming its Firestore claim. The administrator also assigns its separate device-authentication `writerUid`. These are RTDB data assignments, not changes to the rules for every device.

Once its access mapping and rules are in place, the ESP32's first successful upload creates its live record automatically. Importing a placeholder `deviceLive` record is optional. Subsequent readings and Flutter subscriptions require no Function or manual telemetry imports.

Additional test devices require an access mapping once per device. Changes of owner or device identity also require an administrator to update that mapping. Firestore and RTDB remain separate authorization stores: the current app cannot automatically copy ownership into RTDB, and RTDB rules cannot consult the Firestore claim document. This development approach deliberately retains administrator-managed access rather than allowing arbitrary signed-in accounts to claim RTDB paths. Automatic onboarding for customers remains future work; it requires a trusted synchronization service or a separately designed device claim protocol.

Pricing references: [Firebase plans and service quotas](https://firebase.google.com/pricing) and [RTDB billing on Spark](https://firebase.google.com/docs/database/usage/billing).

The initial import is not an automatic claim synchronization service or a history/retention system. Device Authentication account creation is a separate operation and has been completed for this test device. Firestore registry records and the app owner's account were not changed. Cloud rule deployment and access-map synchronization require an authorized Firebase CLI login.

## Publish RTDB rules from the terminal

The repository's root `firebase.json` already points to `database/database.rules.json`. Run these commands from the repository root:

```sh
cd /Users/udmdev/Desktop/Learnings/Youtube/Flutter/yening_ecos
npx -y firebase-tools@latest login --reauth
npx -y firebase-tools@latest deploy --only database --project yening-ecos-development --config firebase.json
```

For the browser sign-in, use the Google account that manages this Firebase project (`contact@yeninginnovation.com`). This CLI login is separate from the app user's Firebase Authentication account and the firmware's device account. If the browser callback cannot reach the terminal, use `npx -y firebase-tools@latest login --reauth --no-localhost` instead.

The deployment publishes only the RTDB security rules configured in `firebase.json`. It leaves existing telemetry and access mappings intact and does not deploy Cloud Functions. No JSON data import is needed for this format migration. Wait for the CLI's successful deployment message before flashing firmware that writes the independent sensor records.

Reference: [Firebase CLI partial deployment](https://firebase.google.com/docs/cli#partial_deploys).

## Validation

All 151 local emulator checks pass and cover the supplied owner/writer identities, independent sensor records, sibling timestamp preservation, unchanged values with new timestamps, continued healthy uploads after one rejected sensor, missing-sensor clearing, record shape/type/range validation, and legacy numeric compatibility. An owner-authenticated realtime stream receives each independent metric event during two-second test cycles. Confirmed and silent PATCH responses and server timestamp resolution are also covered.

The emulator checks in [`../test/database/rtdb_rules_test.mjs`](../test/database/rtdb_rules_test.mjs) use a local demo project and simulated identities. They cover the supplied owner UID, null import semantics, rolling compatibility with existing numeric uploads, percentage boundaries, multiple devices per account, isolated device writers, ownership transfers, heartbeat validation, access-map tampering, and deletion prevention.

From the repository root, with the Firebase CLI and Java installed:

```sh
npx -y firebase-tools@latest emulators:exec --project demo-yening-rtdb --config database/firebase.emulator.json --only database "node test/database/rtdb_rules_test.mjs"
```

References: [RTDB authentication conditions](https://firebase.google.com/docs/database/security/rules-conditions) and [null/delete semantics](https://firebase.google.com/docs/database/flutter/read-and-write).
