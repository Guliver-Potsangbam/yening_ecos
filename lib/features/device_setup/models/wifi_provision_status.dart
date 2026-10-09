class WifiProvisionStatus {
  const WifiProvisionStatus({
    required this.status,
    required this.deviceId,
    this.ipAddress,
    this.ssid,
  });

  final String status;
  final String deviceId;
  final String? ipAddress;
  final String? ssid;

  bool get isConnected {
    return status == 'connected';
  }

  bool get hasConfirmedConnection =>
      isConnected &&
      deviceId.isNotEmpty &&
      ssid != null &&
      ssid!.isNotEmpty &&
      ipAddress != null &&
      ipAddress!.isNotEmpty &&
      ipAddress != '0.0.0.0';

  bool get isFailed {
    return status == 'failed';
  }

  factory WifiProvisionStatus.fromJson(Map<String, dynamic> json) {
    final connected = json['connected'];
    if (connected != null && connected is! bool) {
      throw const FormatException('Invalid connected flag.');
    }
    final status = json['status'] as String?;
    if (status == 'connected' && connected == false) {
      throw const FormatException('Contradictory connection status.');
    }
    if (status == null && connected == null) {
      throw const FormatException('Missing Wi-Fi status.');
    }
    return WifiProvisionStatus(
      status: status ?? (connected == true ? 'connected' : 'connecting'),
      deviceId: json['deviceId'] as String? ?? '',
      ipAddress: (json['ipAddress'] ?? json['ip']) as String?,
      ssid: json['ssid'] as String?,
    );
  }
}
