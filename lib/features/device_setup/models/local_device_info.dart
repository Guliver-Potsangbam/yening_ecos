class LocalDeviceInfo {
  const LocalDeviceInfo({
    required this.apiVersion,
    required this.deviceId,
    required this.deviceName,
    required this.serialNumber,
    required this.deviceTypeId,
    required this.provisioningStatus,
  });

  final String apiVersion;
  final String deviceId;
  final String deviceName;
  final String serialNumber;
  final String deviceTypeId;
  final String provisioningStatus;

  bool get isValid {
    return RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(deviceId) &&
        RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(deviceTypeId);
  }

  factory LocalDeviceInfo.fromJson(Map<String, dynamic> json) {
    return LocalDeviceInfo(
      apiVersion: json['apiVersion'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      serialNumber: json['serialNumber'] as String? ?? '',
      deviceTypeId:
          (json['deviceTypeId'] ?? json['deviceType']) as String? ?? '',
      provisioningStatus: json['provisioningStatus'] as String? ?? '',
    );
  }
}
