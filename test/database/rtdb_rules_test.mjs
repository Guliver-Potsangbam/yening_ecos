import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { setTimeout as delay } from 'node:timers/promises';

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

// Observe actual RTDB events as an app owner, not just the HTTP write response.
async function openLiveStream(path, identity) {
  const controller = new AbortController();
  const deadline = setTimeout(() => controller.abort(), 10000);
  const url = new URL(`http://${emulatorHost}/${path}.json`);
  url.searchParams.set('ns', `${projectId}-default-rtdb`);
  url.searchParams.set('auth', userToken(identity));
  let reader;
  try {
    const response = await fetch(url, {
      headers: { Accept: 'text/event-stream' }, signal: controller.signal,
    });
    assert.equal(response.status, 200);
    reader = response.body.getReader();
  } catch (error) {
    clearTimeout(deadline);
    controller.abort();
    throw error;
  }
  const decoder = new TextDecoder();
  let buffer = '';
  let state = null;
  function replaceAt(parts, value) {
    if (parts.length === 0) { state = structuredClone(value); return; }
    state ??= {};
    let parent = state;
    for (const key of parts.slice(0, -1)) parent = parent[key] ??= {};
    const key = parts.at(-1);
    if (value === null) delete parent[key];
    else parent[key] = structuredClone(value);
  }
  return {
    async next() {
      for (;;) {
        const boundary = buffer.indexOf('\n\n');
        if (boundary < 0) {
          const chunk = await reader.read();
          assert.equal(chunk.done, false, 'RTDB stream ended before a complete snapshot.');
          buffer += decoder.decode(chunk.value, { stream: true }).replaceAll('\r\n', '\n');
          continue;
        }
        const packet = buffer.slice(0, boundary);
        buffer = buffer.slice(boundary + 2);
        const lines = packet.split('\n');
        const event = lines.find((line) => line.startsWith('event:'))?.slice(6).trim();
        if (event === 'keep-alive' || !event) continue;
        assert.ok(event === 'put' || event === 'patch', `Unexpected RTDB event: ${event}`);
        const payload = JSON.parse(lines.filter((line) => line.startsWith('data:'))
          .map((line) => line.slice(5).trim()).join('\n'));
        const base = payload.path.split('/').filter(Boolean);
        if (event === 'put') replaceAt(base, payload.data);
        else {
          for (const [key, value] of Object.entries(payload.data)) {
            replaceAt([...base, ...key.split('/').filter(Boolean)], value);
          }
        }
        return structuredClone(state);
      }
    },
    async close() {
      clearTimeout(deadline);
      await reader.cancel();
      controller.abort();
    },
  };
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
// Rolling compatibility: previously shipped firmware used numeric readings.
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
// Rolling compatibility also retains the earlier nested full-snapshot PATCH.
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
// Earlier firmware's combined two-second commits remain owner-visible.
// Humidity alone changes on the second upload; the third repeats every value.
// Neither case may defer the other fields or suppress the new heartbeat.
const stream = await openLiveStream(live, ownerUid);
try {
  assert.deepEqual(await stream.next(), diagnosticSample);
  checks++;
  const samples = [
    { temperature: 28.4, humidity: 66.4, light: 100 },
    { temperature: 28.4, humidity: 66.5, light: 100 },
    { temperature: 28.4, humidity: 66.5, light: 100 },
  ];
  let previousLastSeen = diagnosticSample.connectivity.lastSeen;
  for (const [index, telemetry] of samples.entries()) {
    if (index > 0) await delay(2000);
    const response = await request(live, 'PATCH', {
      connectivity: { isOnline: true, lastSeen: { '.sv': 'timestamp' } },
      telemetry,
    }, 'device-one');
    assert.equal(response.status, 200);
    const committed = await response.json();
    const observed = await stream.next();
    assert.deepEqual(observed, committed, 'One event must contain the entire committed sample.');
    assert.deepEqual(observed.telemetry, telemetry, 'All three readings belong to this heartbeat.');
    assert.ok(observed.connectivity.lastSeen > previousLastSeen);
    previousLastSeen = observed.connectivity.lastSeen;
    checks++;
  }
} finally {
  await stream.close();
}
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

// Current firmware: each metric value/updatedAt pair is its own atomic write.
const serverTimestamp = { '.sv': 'timestamp' };
function metricUpdate(field, value) {
  return {
    'connectivity/isOnline': true,
    'connectivity/lastSeen': serverTimestamp,
    [`telemetry/${field}`]: { value, updatedAt: serverTimestamp },
  };
}
const metricValues = { temperature: 28.4, humidity: 66.5, light: 100 };
for (const [field, value] of Object.entries(metricValues)) {
  await allowed(live, 'PATCH', metricUpdate(field, value), 'device-one');
}
let records = await (await request(live, 'GET', undefined, ownerUid)).json();
for (const [field, value] of Object.entries(metricValues)) {
  assert.deepEqual(Object.keys(records.telemetry[field]).sort(), ['updatedAt', 'value']);
  assert.equal(records.telemetry[field].value, value);
  assert.equal(typeof records.telemetry[field].updatedAt, 'number');
  checks++;
}

// Real owner stream proves each field updates independently at two-second
// intervals even when its value repeats, preserving all sibling timestamps.
const metricStream = await openLiveStream(live, ownerUid);
try {
  assert.deepEqual(await metricStream.next(), records);
  checks++;
  for (let tick = 0; tick < 2; tick++) {
    await delay(2000);
    for (const [field, value] of Object.entries(metricValues)) {
      const before = structuredClone(records);
      const response = await request(live, 'PATCH', metricUpdate(field, value), 'device-one');
      assert.equal(response.status, 200);
      const committed = await response.json();
      assert.deepEqual(Object.keys(committed.telemetry), [field],
        'The confirmed PATCH must contain exactly one metric.');
      records = await metricStream.next();
      assert.deepEqual(records.telemetry[field], committed.telemetry[field]);
      assert.equal(records.telemetry[field].value, value);
      assert.ok(records.telemetry[field].updatedAt > before.telemetry[field].updatedAt,
        'An unchanged measured value must still advance its own timestamp.');
      assert.equal(records.connectivity.lastSeen, records.telemetry[field].updatedAt);
      for (const sibling of Object.keys(metricValues).filter((name) => name !== field)) {
        assert.deepEqual(records.telemetry[sibling], before.telemetry[sibling],
          `${field} must not refresh or replace ${sibling}.`);
      }
      checks++;
    }
  }
} finally {
  await metricStream.close();
}

// Reject just the malformed write. Healthy metrics are still independently
// uploadable; the rejected field and its timestamp remain unchanged.
await denied(live, 'PATCH', metricUpdate('light', 101), 'device-one');
assert.deepEqual(await (await request(live, 'GET', undefined, ownerUid)).json(), records);
checks++;
await delay(5);
await allowed(live, 'PATCH', metricUpdate('temperature', 29.1), 'device-one');
await allowed(live, 'PATCH', metricUpdate('humidity', 67), 'device-one');
const afterIndependentFailure = await (await request(live, 'GET', undefined, ownerUid)).json();
assert.deepEqual(afterIndependentFailure.telemetry.light, records.telemetry.light);
assert.equal(afterIndependentFailure.telemetry.temperature.value, 29.1);
assert.equal(afterIndependentFailure.telemetry.humidity.value, 67);
checks++;

for (const field of Object.keys(metricValues)) {
  const old = afterIndependentFailure.telemetry[field];
  for (const malformed of [
    { value: old.value },
    { updatedAt: serverTimestamp },
    { value: '25', updatedAt: serverTimestamp },
    { value: true, updatedAt: serverTimestamp },
    { value: old.value, updatedAt: 'today' },
    { value: old.value, updatedAt: true },
    { value: old.value, updatedAt: 0 },
    { value: old.value, updatedAt: Date.now() + 600000 },
    { value: old.value, updatedAt: Date.now() - 120000 },
    { value: old.value, updatedAt: Date.now() + 0.5 },
    { value: old.value, updatedAt: serverTimestamp, rawAdc: 100 },
  ]) {
    await denied(live, 'PATCH', { [`telemetry/${field}`]: malformed }, 'device-one');
  }
  await denied(`${live}/telemetry/${field}/value`, 'PUT', old.value - 1, 'device-one');
  await denied(`${live}/telemetry/${field}/updatedAt`, 'DELETE', undefined, 'device-one');
  await denied(`${live}/telemetry/${field}/value`, 'DELETE', undefined, 'device-one');
}
await denied(live, 'PATCH', metricUpdate('temperature', -40.1), 'device-one');
await denied(live, 'PATCH', metricUpdate('temperature', 80.1), 'device-one');
await denied(live, 'PATCH', metricUpdate('humidity', -0.1), 'device-one');
await denied(live, 'PATCH', metricUpdate('humidity', 100.1), 'device-one');
await denied(live, 'PATCH', metricUpdate('light', -0.1), 'device-one');
await denied(live, 'PATCH', metricUpdate('light', 100.1), 'device-one');
await denied(live, 'PATCH', metricUpdate('light', 50), ownerUid);
await denied(live, 'PATCH', metricUpdate('light', 50), 'another-device');

// Removing an unavailable metric must not erase unrelated healthy records.
await allowed(live, 'PATCH', {
  'connectivity/isOnline': true,
  'connectivity/lastSeen': serverTimestamp,
  'telemetry/temperature': null,
}, 'device-one');
const afterUnavailable = await (await request(live, 'GET', undefined, ownerUid)).json();
assert.equal(afterUnavailable.telemetry.temperature, undefined);
assert.deepEqual(afterUnavailable.telemetry.humidity, afterIndependentFailure.telemetry.humidity);
assert.deepEqual(afterUnavailable.telemetry.light, afterIndependentFailure.telemetry.light);
checks++;
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
