import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yening_ecos/features/device_setup/models/local_device_info.dart';
import 'package:yening_ecos/features/devices/data/device_claim_service.dart';

import 'support/firebase_fakes.dart';

void main() {
  const info = LocalDeviceInfo(
    apiVersion: '1',
    deviceId: 'device-1',
    deviceName: 'EnviroSense',
    serialNumber: 'SN-1',
    deviceTypeId: 'envirosense_basic_v1',
    provisioningStatus: 'connected',
  );
  const devicePath = 'devices/device-1';
  const membershipPath = 'users/owner/devices/device-1';
  late TestAuth auth;
  late TestFirestore firestore;
  late DeviceClaimService service;

  setUp(() {
    auth = TestAuth()..currentUser = TestUser('owner');
    firestore = TestFirestore();
    service = DeviceClaimService(auth: auth, firestore: firestore);
    firestore.records[devicePath] = {
      'deviceId': info.deviceId,
      'deviceName': info.deviceName,
      'serialNumber': info.serialNumber,
      'deviceTypeId': info.deviceTypeId,
      'status': 'claimed',
      'claimedByUid': 'owner',
      'claimedAt': Timestamp.fromMillisecondsSinceEpoch(1234),
    };
  });
  tearDown(() => auth.changes.close());

  test(
    'repairs a missing membership for a device already owned by this account',
    () async {
      await service.claimDevice(deviceInfo: info);
      expect(firestore.updates, isEmpty);
      expect(firestore.writes, [membershipPath]);
      expect(firestore.records[membershipPath]!['deviceId'], info.deviceId);
      expect(
        firestore.records[membershipPath]!['claimedAt'],
        firestore.records[devicePath]!['claimedAt'],
      );
    },
  );

  test('preserves an existing membership and its custom name', () async {
    firestore.records[membershipPath] = {
      'deviceId': info.deviceId,
      'deviceName': 'My bedroom',
    };
    await service.claimDevice(deviceInfo: info);
    expect(firestore.writes, isEmpty);
    expect(firestore.updates, isEmpty);
    expect(firestore.records[membershipPath]!['deviceName'], 'My bedroom');
  });

  test('rejects another owner without writing account membership', () async {
    firestore.records[devicePath]!['claimedByUid'] = 'someone-else';
    await expectLater(
      service.claimDevice(deviceInfo: info),
      throwsA(isA<DeviceClaimException>()),
    );
    expect(firestore.writes, isEmpty);
    expect(firestore.updates, isEmpty);
  });

  test(
    'new claims update registry ownership and create membership atomically',
    () async {
      firestore.records[devicePath]!['status'] = 'unclaimed';
      firestore.records[devicePath]!.remove('claimedByUid');
      firestore.records[devicePath]!.remove('claimedAt');
      await service.claimDevice(deviceInfo: info);
      expect(firestore.updates, [devicePath]);
      expect(firestore.writes, [membershipPath]);
      expect(firestore.records[devicePath]!['claimedByUid'], 'owner');
    },
  );
}
