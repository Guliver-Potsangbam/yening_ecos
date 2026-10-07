class DeviceRegistryRecord {
  const DeviceRegistryRecord({
    required this.deviceId,
    required this.deviceName,
    required this.serialNumber,
    required this.deviceTypeId,
    required this.status,
    this.claimedByUid,
  });

  final String deviceId;
  final String deviceName;
  final String serialNumber;
  final String deviceTypeId;
  final String status;
  final String? claimedByUid;

  bool get isUnclaimed {
    return status == 'unclaimed';
  }

  factory DeviceRegistryRecord.fromMap(Map<String, dynamic> data) {
    return DeviceRegistryRecord(
      deviceId: data['deviceId'] as String? ?? '',
      deviceName: data['deviceName'] as String? ?? '',
      serialNumber: data['serialNumber'] as String? ?? '',
      deviceTypeId: data['deviceTypeId'] as String? ?? '',
      status: data['status'] as String? ?? '',
      claimedByUid: data['claimedByUid'] as String?,
    );
  }
}
