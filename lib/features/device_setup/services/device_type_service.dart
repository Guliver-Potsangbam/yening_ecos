import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/device_type_definition.dart';

class DeviceTypeService {
  DeviceTypeService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<DeviceTypeDefinition?> getDeviceType(String deviceTypeId) async {
    final snapshot = await _firestore
        .collection('deviceTypes')
        .doc(deviceTypeId)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    return DeviceTypeDefinition.fromMap(data);
  }
}
