import 'package:flutter/material.dart';

import '../../core/preferences/temperature_unit_preference.dart';
import 'models/user_device.dart';
import 'services/device_telemetry_service.dart';
import 'widgets/device_telemetry_panel.dart';
import 'widgets/user_device_card.dart';

class DeviceDetailsPage extends StatelessWidget {
  const DeviceDetailsPage({
    super.key,
    required this.device,
    this.telemetrySource,
    this.unitPreference,
  });
  final UserDevice device;
  final DeviceTelemetrySource? telemetrySource;
  final TemperatureUnitPreference? unitPreference;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(title: const Text('Device details')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                UserDeviceCard(
                  device: device,
                  telemetry: DeviceTelemetryPanel(
                    deviceId: device.deviceId,
                    telemetrySource: telemetrySource,
                    unitPreference: unitPreference,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
