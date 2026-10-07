import 'package:flutter/material.dart';

import '../../core/preferences/temperature_unit_preference.dart';
import '../../core/ui/monitoring_background.dart';
import 'models/user_device.dart';
import 'services/device_details_service.dart';
import 'services/device_telemetry_service.dart';
import 'widgets/device_metadata_panel.dart';
import 'widgets/device_telemetry_panel.dart';
import 'widgets/user_device_card.dart';

class DeviceDetailsPage extends StatefulWidget {
  const DeviceDetailsPage({
    super.key,
    required this.device,
    this.telemetrySource,
    this.unitPreference,
    this.metadataSource,
  });
  final UserDevice device;
  final DeviceTelemetrySource? telemetrySource;
  final TemperatureUnitPreference? unitPreference;
  final DeviceDetailsSource? metadataSource;

  @override
  State<DeviceDetailsPage> createState() => _DeviceDetailsPageState();
}

class _DeviceDetailsPageState extends State<DeviceDetailsPage> {
  late Stream<DeviceDetailsState> _metadata;

  @override
  void initState() {
    super.initState();
    _watchMetadata();
  }

  void _watchMetadata() {
    try {
      _metadata = (widget.metadataSource ?? DeviceDetailsService().watchDevice)(
        widget.device.deviceId,
      );
    } catch (_) {
      _metadata = Stream.value(const DeviceDetailsState.unavailable());
    }
  }

  @override
  void didUpdateWidget(DeviceDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.deviceId != widget.device.deviceId ||
        oldWidget.metadataSource != widget.metadataSource) {
      _watchMetadata();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(title: const Text('Device details')),
      body: MonitoringBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: StreamBuilder<DeviceDetailsState>(
                stream: _metadata,
                builder: (context, snapshot) {
                  // StreamBuilder retains old data when its stream changes.
                  // Clear it while the new device or retry is still loading.
                  final metadata =
                      snapshot.connectionState == ConnectionState.waiting
                      ? const DeviceDetailsState.loading()
                      : snapshot.hasError
                      ? const DeviceDetailsState.unavailable()
                      : snapshot.data ?? const DeviceDetailsState.loading();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      UserDeviceCard(
                        device: metadata.details?.device ?? widget.device,
                        telemetry: DeviceTelemetryPanel(
                          key: ValueKey(
                            'details-telemetry-${widget.device.deviceId}',
                          ),
                          deviceId: widget.device.deviceId,
                          telemetrySource: widget.telemetrySource,
                          unitPreference: widget.unitPreference,
                        ),
                      ),
                      const SizedBox(height: 18),
                      DeviceMetadataPanel(
                        state: metadata,
                        onRetry: () => setState(_watchMetadata),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
