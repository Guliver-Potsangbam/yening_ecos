import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const emulatorHost = process.env.FIREBASE_DATABASE_EMULATOR_HOST;
assert.match(emulatorHost ?? '', /^(127\.0\.0\.1|localhost):\d+$/,
  'These tests require a local Realtime Database emulator.');
const projectId = 'demo-yening-rtdb';
const deviceId = 'YEC-DEV-000001';
const seed = JSON.parse(await readFile(new URL('../../database/rtdb.import.json', import.meta.url)));
const ownerUid = seed.deviceAccess[deviceId].ownerUid;
const seededWriterUid = seed.deviceAccess[deviceId].writerUid;
assert.equal(typeof seededWriterUid, 'string', 'Import must include the registered device writer UID.');
assert.notEqual(seededWriterUid, ownerUid, 'The device account must differ from the app owner.');
const rules = JSON.parse(await readFile(new URL('../../database/database.rules.json', import.meta.url)));
const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
function userToken(uid) {
  const now = Math.floor(Date.now() / 1000);
  return `${encode({ alg: 'none', typ: 'JWT' })}.${encode({
    iss: `https://securetoken.google.com/${projectId}`,
    aud: projectId, sub: uid, user_id: uid, auth_time: now, iat: now,
    exp: now + 3600, firebase: { sign_in_provider: 'custom', identities: {} },
  })}.`;
}
let checks = 0;
async function request(path, method = 'GET', value, identity = null, silent = false) {
  const url = new URL(`http://${emulatorHost}/${path}.json`);
  url.searchParams.set('ns', `${projectId}-default-rtdb`);
  if (silent) url.searchParams.set('print', 'silent');
  const headers = { 'Content-Type': 'application/json' };
  if (identity === 'admin') headers.Authorization = 'Bearer owner';
  else if (identity) url.searchParams.set('auth', userToken(identity));
  return fetch(url, { method, headers, body: value === undefined ? undefined : JSON.stringify(value) });
}
async function allowed(path, method, value, identity) {
  const response = await request(path, method, value, identity);
  assert.equal(response.status, 200, `${method} ${path} as ${identity}: ${await response.text()}`);
  checks++;
}
async function denied(path, method, value, identity) {
  const response = await request(path, method, value, identity);
  assert.equal(response.status, 401, `${method} ${path} as ${identity} unexpectedly allowed: ${await response.text()}`);
  checks++;
}
const live = `deviceLive/${deviceId}`;
const access = `deviceAccess/${deviceId}`;
await allowed('.settings/rules', 'PUT', rules, 'admin');
await allowed('', 'PUT', seed, 'admin');
const normalizedSeed = structuredClone(seed);
delete normalizedSeed.deviceLive[deviceId].telemetry;
assert.deepEqual(await (await request('', 'GET', undefined, 'admin')).json(), normalizedSeed);
checks++;
await allowed(live, 'GET', undefined, ownerUid);
await allowed(live, 'GET', undefined, seededWriterUid);
await allowed(live, 'PATCH', {
  'connectivity/isOnline': true,
  'connectivity/lastSeen': { '.sv': 'timestamp' },
  'telemetry/temperature': 24.5,
  'telemetry/humidity': 55.2,
}, seededWriterUid);
await denied(live, 'GET', undefined, 'another-owner');
await denied(live, 'PATCH', { 'telemetry/light': 100 }, ownerUid);
await denied(live, 'PATCH', { 'telemetry/light': 100 }, 'device-one');
await allowed(access, 'PUT', { enabled: true, ownerUid: ownerUid, writerUid: 'device-one' }, 'admin');
await allowed(live, 'GET', undefined, ownerUid);
await allowed(live, 'GET', undefined, 'device-one');
await denied(live, 'GET', undefined, null);
await denied(live, 'GET', undefined, 'another-owner');
await denied('deviceLive', 'GET', undefined, ownerUid);
await denied(live, 'PATCH', { 'telemetry/light': 100 }, ownerUid);
await denied(live, 'PATCH', { 'telemetry/light': 100 }, 'another-device');
await denied(access, 'PUT', { enabled: true, ownerUid: 'another-owner', writerUid: 'another-device' }, 'another-owner');
await denied(live, 'PATCH', { deviceName: 'Edited' }, ownerUid);
await denied('deviceMetadata', 'GET', undefined, ownerUid);
await denied('schema', 'GET', undefined, ownerUid);
await denied(access, 'GET', undefined, ownerUid);

// First upload creates the live record without importing placeholder readings.
await allowed(live, 'DELETE', undefined, 'admin');
// Current ESP32 update with DHT22 and relative light readings.
await allowed(live, 'PATCH', {
  'connectivity/isOnline': true,
  'connectivity/lastSeen': { '.sv': 'timestamp' },
  'telemetry/temperature': 24.5,
  'telemetry/humidity': 55.2,
  'telemetry/light': 53.2,
}, 'device-one');
const firstReading = await request(live, 'GET', undefined, ownerUid);
assert.equal(firstReading.status, 200);
const firstValue = await firstReading.json();
assert.deepEqual(firstValue.telemetry, { temperature: 24.5, humidity: 55.2, light: 53.2 });
assert.equal(firstValue.connectivity.isOnline, true);
assert.ok(Math.abs(Date.now() - firstValue.connectivity.lastSeen) < 60000);
checks++;
// The SDK's confirmed silent PATCH uses nested objects, not separate writes.
const silentSample = {
  connectivity: { isOnline: true, lastSeen: { '.sv': 'timestamp' } },
  telemetry: { temperature: 26.1, humidity: 48.3, light: 5 },
};
const silentResponse = await request(live, 'PATCH', silentSample, 'device-one', true);
assert.equal(silentResponse.status, 204);
assert.equal(await silentResponse.text(), '');
const confirmedSample = await (await request(live, 'GET', undefined, ownerUid)).json();
assert.deepEqual(confirmedSample.telemetry, silentSample.telemetry);
assert.equal(confirmedSample.connectivity.isOnline, true);
assert.ok(Math.abs(Date.now() - confirmedSample.connectivity.lastSeen) < 60000);
checks++;
// Rejecting one invalid reading must reject the whole snapshot and heartbeat.
await denied(live, 'PATCH', {
  ...silentSample,
  telemetry: { temperature: 30, humidity: 70, light: 101 },
}, 'device-one');
assert.deepEqual(await (await request(live, 'GET', undefined, ownerUid)).json(), confirmedSample);
checks++;
// Diagnostic mode gets the resolved server timestamp from the same PATCH.
// Firmware can measure commit intervals without issuing a follow-up GET.
const diagnosticResponse = await request(live, 'PATCH', {
  connectivity: { isOnline: true, lastSeen: { '.sv': 'timestamp' } },
  telemetry: { temperature: 28.5, humidity: 62.3, light: 0 },
}, 'device-one');
assert.equal(diagnosticResponse.status, 200);
const diagnosticSample = await diagnosticResponse.json();
assert.deepEqual(diagnosticSample.telemetry, { temperature: 28.5, humidity: 62.3, light: 0 });
assert.equal(typeof diagnosticSample.connectivity.lastSeen, 'number');
assert.ok(Math.abs(Date.now() - diagnosticSample.connectivity.lastSeen) < 60000);
assert.deepEqual(await (await request(live, 'GET', undefined, ownerUid)).json(), diagnosticSample);
checks++;
// A DHT22 failure must not stop light uploads or leave stale DHT values visible.
await allowed(live, 'PATCH', {
  'connectivity/isOnline': true,
  'connectivity/lastSeen': { '.sv': 'timestamp' },
  'telemetry/temperature': null,
  'telemetry/humidity': null,
  'telemetry/light': 25,
}, 'device-one');
assert.deepEqual(await (await request(`${live}/telemetry`, 'GET', undefined, ownerUid)).json(), { light: 25 });
checks++;
await allowed(live, 'PATCH', { 'telemetry/light': 0 }, 'device-one');
await allowed(live, 'PATCH', { 'telemetry/light': 100 }, 'device-one');
await allowed(live, 'PATCH', { 'telemetry/light': 53.2 }, 'device-one');
for (const reading of [-0.1, 100.1, 4095, '53.2', true, { percent: 50 }]) {
  await denied(live, 'PATCH', { 'telemetry/light': reading }, 'device-one');
}
for (const [field, value] of [['temperature', -41], ['temperature', 81], ['humidity', -1], ['humidity', 101]]) {
  await denied(live, 'PATCH', { [`telemetry/${field}`]: value }, 'device-one');
}
await denied(live, 'PATCH', { 'telemetry/lux': 100 }, 'device-one');
await denied(live, 'PATCH', { 'telemetry/ldrRaw': 100 }, 'device-one');
await denied(live, 'PATCH', { 'telemetry/temperature': '24' }, 'device-one');
await denied(live, 'PATCH', { 'connectivity/lastSeen': Date.now() + 600000 }, 'device-one');
await denied(live, 'PATCH', { 'connectivity/lastSeen': 0 }, 'device-one');
await denied(live, 'PATCH', { 'connectivity/isOnline': 'true' }, 'device-one');
await denied(live, 'PATCH', { 'connectivity/password': 'must-not-be-stored' }, 'device-one');
await denied(live, 'PATCH', { schemaVersion: 2 }, 'device-one');
await denied(live, 'DELETE', undefined, 'device-one');
await denied(live, 'PATCH', { connectivity: null }, 'device-one');
await denied(live, 'PATCH', { 'connectivity/lastSeen': null }, 'device-one');
await allowed(live, 'PATCH', { 'connectivity/isOnline': false }, 'device-one');
await allowed(live, 'PATCH', { 'telemetry/light': null }, 'device-one');

// One account can own several devices while each writer remains isolated.
const secondDevice = 'YEC-DEV-000002';
const secondLive = `deviceLive/${secondDevice}`;
await allowed(secondLive, 'PUT', normalizedSeed.deviceLive[deviceId], 'admin');
await allowed(`deviceAccess/${secondDevice}`, 'PUT', {
  enabled: true, ownerUid: ownerUid, writerUid: 'device-two',
}, 'admin');
await allowed(live, 'GET', undefined, ownerUid);
await allowed(secondLive, 'GET', undefined, ownerUid);
await denied(secondLive, 'GET', undefined, 'owner-with-no-devices');
await denied(secondLive, 'PATCH', { 'telemetry/light': 50 }, 'device-one');
await denied(live, 'PATCH', { 'telemetry/light': 50 }, 'device-two');
await allowed(secondLive, 'PATCH', {
  'connectivity/lastSeen': { '.sv': 'timestamp' }, 'telemetry/light': 50,
}, 'device-two');
await allowed(access, 'PATCH', { ownerUid: 'owner-two' }, 'admin');
await denied(live, 'GET', undefined, ownerUid);
await allowed(live, 'GET', undefined, 'owner-two');
await denied(secondLive, 'GET', undefined, 'owner-two');
await allowed(secondLive, 'GET', undefined, ownerUid);
await allowed(access, 'PATCH', { ownerUid: ownerUid }, 'admin');

await allowed(access, 'PATCH', { enabled: false }, 'admin');
await denied(live, 'GET', undefined, ownerUid);
await denied(live, 'PATCH', { 'telemetry/light': 100 }, 'device-one');
await allowed(access, 'PUT', { enabled: true, ownerUid: 'same-user', writerUid: 'same-user' }, 'admin');
await denied(live, 'PATCH', { 'telemetry/light': 100 }, 'same-user');
await denied('deviceLive/UNREGISTERED', 'PATCH', { 'telemetry/light': 100 }, 'device-one');
console.log(`${checks} RTDB import and authorization checks passed.`);
