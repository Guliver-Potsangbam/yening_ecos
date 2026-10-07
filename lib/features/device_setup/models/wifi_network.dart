import 'dart:convert';

class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.rssi,
    required this.isOpen,
    required this.isSupported,
    required this.security,
  });

  final String ssid;
  final int rssi;
  final bool isOpen;
  final bool isSupported;
  final String security;

  String get signalLabel => rssi >= -60
      ? 'Strong'
      : rssi >= -75
      ? 'Fair'
      : 'Weak';

  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    final ssid = json['ssid'];
    final rssi = json['rssi'];
    final isOpen = json['isOpen'];
    final isSupported = json['isSupported'];
    final security = json['security'];
    if (ssid is! String ||
        utf8.encode(ssid).length > 32 ||
        ssid.contains('\u0000') ||
        rssi is! int ||
        rssi < -127 ||
        rssi > 0 ||
        isOpen is! bool ||
        isSupported is! bool ||
        security is! String) {
      throw const FormatException('Invalid Wi-Fi network fields.');
    }
    return WifiNetwork(
      ssid: ssid,
      rssi: rssi,
      isOpen: isOpen,
      isSupported: isSupported,
      security: security,
    );
  }
}
