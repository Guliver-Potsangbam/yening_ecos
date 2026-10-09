import assert from 'node:assert/strict';

const project = process.env.GCLOUD_PROJECT || 'demo-yening-setup';
assert.ok(project.startsWith('demo-'), 'Only run against a local demo project');
const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.ok(host, 'Firestore emulator is required');
const root = `projects/${project}/databases/(default)/documents`;
const base = `http://${host}/v1/${root}`;
let checks = 0;
function token(uid) {
  if (uid === 'admin') return 'owner';
  if (!uid) return null;
  const now = Math.floor(Date.now() / 1000);
  const encode = obj => Buffer.from(JSON.stringify(obj)).toString('base64url');
  return `${encode({alg:'none',typ:'JWT'})}.${encode({iss:`https://securetoken.google.com/${project}`,aud:project,sub:uid,user_id:uid,iat:now,exp:now+3600,auth_time:now,email:`${uid}@example.com`,firebase:{sign_in_provider:'password'}})}.`;
}
function value(raw) {
  if (typeof raw === 'boolean') return {booleanValue:raw};
  if (typeof raw === 'string') return {stringValue:raw};
  if (typeof raw === 'number') return {integerValue:String(raw)};
  if (raw instanceof Date) return {timestampValue:raw.toISOString()};
  return {mapValue:{fields:fields(raw)}};
}
function fields(data) { return Object.fromEntries(Object.entries(data).map(([key,v]) => [key,value(v)])); }
function write(path, data, timestamps = [], merge = true) {
  return {update:{name:`${root}/${path}`,fields:fields(data)},
    ...(merge ? {updateMask:{fieldPaths:Object.keys(data)}} : {}),
    ...(timestamps.length ? {updateTransforms:timestamps.map(fieldPath => ({fieldPath,setToServerValue:'REQUEST_TIME'}))} : {})};
}
async function request(method, path, uid, body) {
  const credential = token(uid);
  const response = await fetch(`${base}${path}`, {method,headers:{'Content-Type':'application/json',...(credential ? {Authorization:`Bearer ${credential}`} : {})},...(body ? {body:JSON.stringify(body)} : {})});
  return {status:response.status, body:await response.json()};
}
async function commit(uid, writes, expected, label) {
  const result = await request('POST', ':commit', uid, {writes});
  assert.equal(result.status, expected, `${label}: ${JSON.stringify(result.body)}`);
  checks++;
}
const original = {deviceId:'device-1',deviceName:'Grow room',serialNumber:'SN-1',deviceTypeId:'model-1',status:'unclaimed',provisioningStatus:'unprovisioned',active:true,firmware:{version:'1.0.0'}};
const owned = {...original,status:'claimed',claimedByUid:'owner',claimedAt:new Date('2026-01-01T00:00:00Z')};
const seed = data => commit('admin',[write('devices/device-1',data,[],false)],200,'seed');
const provision = {provisioningStatus:'provisioned'};
const stamps = ['provisionedAt','updatedAt'];
await seed(original);
await commit('owner',[
  write('devices/device-1',{status:'claimed',claimedByUid:'owner',...provision},['claimedAt',...stamps]),
  write('users/owner/devices/device-1',{deviceId:'device-1',deviceName:'Grow room',serialNumber:'SN-1',deviceTypeId:'model-1'},['claimedAt','updatedAt'],false)
],200,'claim and provisioning/membership commit together');
await commit('owner',[write('devices/device-1',provision,stamps)],200,'owner repeats setup');
for (const uid of ['other',null]) {
  await commit(uid,[write('devices/device-1',provision,stamps)],403,'nonowner cannot reconnect');
}
for (const changes of [
  {...provision,claimedByUid:'other'},
  {...provision,status:'unclaimed'},
  {...provision,claimedAt:new Date()},
  {...provision,serialNumber:'SN-2'},
  {...provision,deviceTypeId:'model-2'},
  {...provision,firmware:{version:'2.0.0'}},
  {...provision,wifiPassword:'never-store-me'},
  {...provision,active:false},
  {provisioningStatus:'unprovisioned'}
]) await commit('owner',[write('devices/device-1',changes,stamps)],403,'owner cannot modify registry/ownership outside provisioning fields');
await commit('owner',[write('devices/device-1',{...provision,provisionedAt:new Date('2020-01-01T00:00:00Z')},['updatedAt'])],403,'provisioning requires server timestamp');
await seed(owned);
await commit('owner',[write('devices/device-1',provision,stamps)],200,'repair already-claimed unprovisioned record');
await seed(original);
await commit('owner',[write('devices/device-1',provision,stamps)],403,'cannot provision registry as owner before a claim');
await commit('owner',[write('devices/device-1',{status:'claimed',claimedByUid:'other',...provision},['claimedAt',...stamps])],403,'claim cannot assign another account');
await commit('owner',[write('devices/device-1',{status:'claimed',claimedByUid:'owner',deviceName:'Overwrite',...provision},['claimedAt',...stamps])],403,'claim cannot edit factory metadata');
await seed({...owned,claimedByUid:'other'});
await commit('owner',[
  write('devices/device-1',provision,stamps),
  write('users/owner/devices/device-1',{deviceId:'device-1',deviceName:'Hijack',serialNumber:'SN-1',deviceTypeId:'model-1'},[],false)
],403,'failed owner update does not commit membership');
const persisted = await request('GET','/users/owner/devices/device-1','admin');
assert.equal(persisted.body.fields.deviceName.stringValue,'Grow room');
checks++;
console.log(`${checks} Firestore setup-rule checks passed.`);
