import 'package:flutter/material.dart';

enum AlertSeverity { critical, warning, info }

class DeviceAlert {
  const DeviceAlert({
    required this.title,
    required this.message,
    required this.deviceName,
    required this.time,
    required this.severity,
    required this.icon,
    this.isUnread = true,
  });

  final String title;
  final String message;
  final String deviceName;
  final String time;
  final AlertSeverity severity;
  final IconData icon;
  final bool isUnread;
}
