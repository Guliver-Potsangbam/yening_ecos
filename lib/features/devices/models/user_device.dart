class UserDevice {
  const UserDevice({
    required this.deviceId,
    required this.deviceName,
    required this.serialNumber,
    required this.deviceTypeId,
  });

  final String deviceId;
  final String deviceName;
  final String serialNumber;
  final String deviceTypeId;

  factory UserDevice.fromMap(String documentId, Map<String, dynamic> data) {
    String text(String key) {
      final value = data[key];
      return value is String ? value.trim() : '';
    }

    final name = text('deviceName');
    return UserDevice(
      deviceId: documentId,
      deviceName: name.isEmpty ? documentId : name,
      serialNumber: text('serialNumber'),
      deviceTypeId: text('deviceTypeId'),
    );
  }
}
