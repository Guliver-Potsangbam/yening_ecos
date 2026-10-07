# Minimal EnviroSense RTDB contract

[`rtdb.import.json`](rtdb.import.json) is the initial import for `YEC-DEV-000001`, owned by Firebase Authentication UID `LfyDXygCVocPj51mja8D8JvvMUG3` (`test@example.com`, supplied by the owner). It contains two branches: `deviceLive` for runtime data and `deviceAccess` for authorization. Importing at the database root replaces data at that location; this file initializes a database rather than migrating existing readings.

Firestore holds the `devices`, `deviceTypes`, and `users` collections. Device names, serial numbers, types, firmware versions, claim/provisioning status, hardware descriptions, telemetry definitions, supported units, and control definitions stay there. RTDB holds no duplicate metadata, account emails, passwords, or tokens.

## Live data

| Path under `deviceLive/<deviceId>` | Stored value |
| --- | --- |
| `telemetry/temperature` | Numeric Celsius, -40 to 80 |
| `telemetry/humidity` | Numeric relative humidity percent, 0 to 100 |
| `telemetry/light` | Numeric relative light percent, 0 to 100 |
| `connectivity/lastSeen` | Firebase server timestamp in Unix milliseconds |
| `connectivity/isOnline` | Boolean reported by the device |

`light` matches the supplied Firestore device-type definition. The firmware samples the LDR on confirmed GPIO34, averages 16 readings, and normalizes them to a bounded relative percentage using the dark/bright reference values in `device_config.h`. The initial endpoints assume brighter light raises the ADC reading; actual module polarity and measured calibration remain to be confirmed. The contract accepts decimal percentages; it does not label raw ADC counts as percent or lux. Flutter displays a third live light gauge on Home and Device Details. A DHT22 failure does not stop light uploads; unavailable DHT fields are cleared rather than shown as fresh values.

The import uses null readings to show the three expected field names without inventing measurements. RTDB removes null values and empty objects, so the telemetry branch appears when the device uploads real values. Zero remains a valid measurement. `isOnline: false` and `lastSeen: 0` indicate that no heartbeat has been recorded in this seed. Claimed/provisioned status remains in Firestore; it does not prove that a fresh cloud heartbeat exists. The app already checks heartbeat freshness against a 60-second threshold and converts Celsius to Fahrenheit for display.

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

## Validation

All 73 emulator checks passed, covering the supplied owner UID, registered device writer UID, fractional light percentages, creation of the live record on its first firmware upload without a placeholder import, and continued light-only uploads when the DHT22 is unavailable.

The emulator checks in [`../test/database/rtdb_rules_test.mjs`](../test/database/rtdb_rules_test.mjs) use a local demo project and simulated identities. They cover the supplied owner UID, null import semantics, compatibility with the existing temperature/humidity upload, percentage boundaries, multiple devices per account, isolated device writers, ownership transfers, heartbeat validation, access-map tampering, and deletion prevention.

From the repository root, with the Firebase CLI and Java installed:

```sh
firebase emulators:exec --project demo-yening-rtdb --config database/firebase.emulator.json --only database "node test/database/rtdb_rules_test.mjs"
```

References: [RTDB authentication conditions](https://firebase.google.com/docs/database/security/rules-conditions) and [null/delete semantics](https://firebase.google.com/docs/database/flutter/read-and-write).
