import 'package:flutter/material.dart';

import '../device_setup/add_device_page.dart';
import '../../core/preferences/temperature_unit_preference.dart';
import '../devices/device_details_page.dart';
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

  void _openAddDevice(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AddDevicePage()));
  }

  void _openDevice(UserDevice device) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceDetailsPage(
          device: device,
          telemetrySource: widget.telemetrySource,
          unitPreference: widget.unitPreference,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserDevicesState>(
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
          return const Center(child: CircularProgressIndicator());
        }
        if (state.devices.isEmpty) {
          return HomeEmptyState(onAddDevice: () => _openAddDevice(context));
        }
        final theme = Theme.of(context);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                'Your environment',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${state.devices.length} ${state.devices.length == 1 ? 'device' : 'devices'} added to your account.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              for (final device in state.devices)
                UserDeviceCard(
                  key: ValueKey(device.deviceId),
                  device: device,
                  onTap: () => _openDevice(device),
                  telemetry: DeviceTelemetryPanel(
                    deviceId: device.deviceId,
                    telemetrySource: widget.telemetrySource,
                    unitPreference: widget.unitPreference,
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _openAddDevice(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Device'),
              ),
            ],
          ),
        );
      },
    );
  }
}
