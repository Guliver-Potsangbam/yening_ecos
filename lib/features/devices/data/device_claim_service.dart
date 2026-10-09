import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/device_registry_record.dart';
import '../../device_setup/models/local_device_info.dart';
import '../../device_setup/models/wifi_provision_status.dart';

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

  Future<void> claimDevice({
    required LocalDeviceInfo deviceInfo,
    WifiProvisionStatus? wifiConfirmation,
    bool requireExistingOwner = false,
  }) async {
    if (wifiConfirmation != null &&
        (!wifiConfirmation.hasConfirmedConnection ||
            wifiConfirmation.deviceId != deviceInfo.deviceId)) {
      throw const DeviceClaimException(
        'A successful Wi-Fi connection for this device must be confirmed before updating registration.',
      );
    }
    if (requireExistingOwner && wifiConfirmation == null) {
      throw const DeviceClaimException(
        'Confirm the device’s new Wi-Fi connection before saving it.',
      );
    }
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

      if (requireExistingOwner &&
          (device.status != 'claimed' || device.claimedByUid != user.uid)) {
        throw const DeviceClaimException(
          'Only the current owner can change this device’s Wi-Fi.',
        );
      }
      if (!device.isUnclaimed && device.claimedByUid != user.uid) {
        throw const DeviceClaimException(
          'This device is already registered to another account.',
        );
      }
      // Read both records before writing. A repeat setup preserves membership,
      // its custom name, original claim time, and the existing owner.
      final membership = await transaction.get(userDeviceRef);
      final updates = <String, dynamic>{};
      if (device.isUnclaimed) {
        updates.addAll({
          'status': 'claimed',
          'claimedByUid': user.uid,
          'claimedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (wifiConfirmation != null) {
        updates.addAll({
          'provisioningStatus': 'provisioned',
          'provisionedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (updates.isNotEmpty) transaction.update(deviceRef, updates);
      if (membership.exists) return;

      transaction.set(userDeviceRef, {
        'deviceId': deviceInfo.deviceId,
        'deviceName': deviceInfo.deviceName,
        'serialNumber': deviceInfo.serialNumber,
        'deviceTypeId': deviceInfo.deviceTypeId,
        'claimedAt': device.isUnclaimed
            ? FieldValue.serverTimestamp()
            : data['claimedAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
