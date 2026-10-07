import 'package:flutter/material.dart';

import '../../core/preferences/temperature_unit_preference.dart';
import '../../core/ui/monitoring_background.dart';
import '../devices/models/user_device.dart';
import '../devices/services/device_telemetry_service.dart';
import '../devices/services/user_devices_service.dart';
import '../devices/widgets/device_telemetry_panel.dart';
import '../devices/widgets/user_device_card.dart';
import 'widgets/home_empty_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.devicesStream,
    this.telemetrySource,
    this.unitPreference,
  });

  final Stream<UserDevicesState>? devicesStream;
  final DeviceTelemetrySource? telemetrySource;
  final TemperatureUnitPreference? unitPreference;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Stream<UserDevicesState> _devices;
  String? _selectedDeviceId;

  @override
  void initState() {
    super.initState();
    _watchDevices();
  }

  void _watchDevices() {
    _devices =
        widget.devicesStream ?? UserDevicesService().watchCurrentUserDevices();
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.devicesStream != widget.devicesStream) _watchDevices();
  }

  Future<void> _switchDevice(
    List<UserDevice> devices,
    String selectedId,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                'Select a device',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: devices.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return ListTile(
                    key: ValueKey('select-${device.deviceId}'),
                    leading: const Icon(Icons.sensors_rounded),
                    title: Text(device.deviceName),
                    subtitle: Text(device.deviceId),
                    selected: device.deviceId == selectedId,
                    trailing: device.deviceId == selectedId
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.of(context).pop(device.deviceId),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null || selected == _selectedDeviceId) return;
    setState(() => _selectedDeviceId = selected);
  }

  @override
  Widget build(BuildContext context) {
    return MonitoringBackground(
      child: StreamBuilder<UserDevicesState>(
        stream: _devices,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Unable to load your devices. Check your internet connection.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(_watchDevices),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final state = snapshot.data;
          if (state == null || state.isLoading) {
            _selectedDeviceId = null;
            return const Center(child: CircularProgressIndicator());
          }
          if (state.devices.isEmpty) {
            _selectedDeviceId = null;
            return const HomeEmptyState();
          }
          final device = state.devices.firstWhere(
            (device) => device.deviceId == _selectedDeviceId,
            orElse: () => state.devices.first,
          );
          _selectedDeviceId = device.deviceId;
          final theme = Theme.of(context);
          return ColoredBox(
            color: Colors.transparent,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Your environment',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            if (state.devices.length >= 2) ...[
                              const SizedBox(width: 12),
                              IconButton.filledTonal(
                                tooltip: 'Switch device',
                                onPressed: () => _switchDevice(
                                  state.devices,
                                  device.deviceId,
                                ),
                                icon: const Icon(Icons.swap_horiz_rounded),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: [
                            UserDeviceCard(
                              key: ValueKey(device.deviceId),
                              device: device,
                              showSerialNumber: false,
                              telemetry: DeviceTelemetryPanel(
                                deviceId: device.deviceId,
                                telemetrySource: widget.telemetrySource,
                                unitPreference: widget.unitPreference,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
