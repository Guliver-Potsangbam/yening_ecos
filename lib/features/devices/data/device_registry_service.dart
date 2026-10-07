import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/device_registry_record.dart';

class DeviceRegistryService {
  DeviceRegistryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<DeviceRegistryRecord?> getDevice(String deviceId) async {
    final snapshot = await _firestore.collection('devices').doc(deviceId).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    return DeviceRegistryRecord.fromMap(data);
  }
}
