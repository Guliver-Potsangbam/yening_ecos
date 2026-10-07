class DeviceTypeDefinition {
  const DeviceTypeDefinition({
    required this.deviceTypeId,
    required this.deviceTypeName,
    required this.status,
    required this.active,
  });

  final String deviceTypeId;
  final String deviceTypeName;
  final String status;
  final bool active;

  bool get isAvailable {
    return active && status == 'active';
  }

  factory DeviceTypeDefinition.fromMap(Map<String, dynamic> data) {
    return DeviceTypeDefinition(
      deviceTypeId: data['deviceTypeId'] as String? ?? '',
      deviceTypeName: data['deviceTypeName'] as String? ?? '',
      status: data['status'] as String? ?? '',
      active: data['active'] as bool? ?? false,
    );
  }
}
