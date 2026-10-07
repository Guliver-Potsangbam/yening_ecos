import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/device_registry_record.dart';
import '../../device_setup/models/local_device_info.dart';

class DeviceClaimException implements Exception {
  const DeviceClaimException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DeviceClaimService {
  DeviceClaimService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> claimDevice({required LocalDeviceInfo deviceInfo}) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw const DeviceClaimException(
        'You must be signed in to add a device.',
      );
    }

    final deviceRef = _firestore.collection('devices').doc(deviceInfo.deviceId);

    final userDeviceRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(deviceInfo.deviceId);

    await _firestore.runTransaction((transaction) async {
      final deviceSnapshot = await transaction.get(deviceRef);

      if (!deviceSnapshot.exists) {
        throw const DeviceClaimException(
          'This device is not registered in Yening Ecos.',
        );
      }

      final data = deviceSnapshot.data();

      if (data == null) {
        throw const DeviceClaimException(
          'The device registry record is empty.',
        );
      }

      final device = DeviceRegistryRecord.fromMap(data);

      if (device.deviceId != deviceInfo.deviceId) {
        throw const DeviceClaimException(
          'The device identity does not match its registry record.',
        );
      }

      if (device.serialNumber != deviceInfo.serialNumber) {
        throw const DeviceClaimException(
          'The device serial number does not match its registry record.',
        );
      }

      if (device.deviceTypeId != deviceInfo.deviceTypeId) {
        throw const DeviceClaimException(
          'The device type does not match its registry record.',
        );
      }

      if (!device.isUnclaimed) {
        if (device.claimedByUid == user.uid) {
          // A previously claimed device may lack its account-list entry.
          // Keep an existing entry (including its name) and backfill a missing
          // one without attempting another ownership transition.
          final membership = await transaction.get(userDeviceRef);
          if (membership.exists) return;
        } else {
          throw const DeviceClaimException(
            'This device is already registered to another account.',
          );
        }
      }

      if (device.isUnclaimed) {
        transaction.update(deviceRef, {
          'status': 'claimed',
          'claimedByUid': user.uid,
          'claimedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.set(userDeviceRef, {
        'deviceId': deviceInfo.deviceId,
        'deviceName': deviceInfo.deviceName,
        'serialNumber': deviceInfo.serialNumber,
        'deviceTypeId': deviceInfo.deviceTypeId,
        'claimedAt': data['claimedAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
