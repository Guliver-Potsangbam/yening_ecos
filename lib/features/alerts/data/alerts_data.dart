import '../models/alert_models.dart';

import 'package:flutter/material.dart';

class AlertsData {
  AlertsData._();

  static const List<DeviceAlert> all = [
    DeviceAlert(
      title: 'VOC level increased',
      message: 'VOC concentration is above the preferred operating range.',
      deviceName: 'GasChecker-01',
      time: '8 min ago',
      severity: AlertSeverity.warning,
      icon: Icons.cloud_outlined,
    ),
    DeviceAlert(
      title: 'CO₂ level rising',
      message:
          'CO₂ concentration has increased compared with the previous reading.',
      deviceName: 'GasChecker-01',
      time: '24 min ago',
      severity: AlertSeverity.info,
      icon: Icons.co2_rounded,
    ),
    DeviceAlert(
      title: 'Water quality changed',
      message: 'Turbidity has changed from the previous measurement.',
      deviceName: 'WaterSense-01',
      time: '42 min ago',
      severity: AlertSeverity.warning,
      icon: Icons.opacity_rounded,
    ),
  ];

  static List<DeviceAlert> get unread {
    return all.where((alert) => alert.isUnread).toList();
  }

  static int get unreadCount {
    return unread.length;
  }

  static List<DeviceAlert> latest([int count = 3]) {
    return all.take(count).toList();
  }
}
