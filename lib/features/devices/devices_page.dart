import 'package:flutter/material.dart';

import '../device_setup/add_device_page.dart';
import '../../widgets/app_empty_state.dart';
import '../../core/preferences/temperature_unit_preference.dart';
import 'device_details_page.dart';
import 'models/user_device.dart';
import 'services/device_telemetry_service.dart';
import 'services/user_devices_service.dart';
import 'widgets/user_device_card.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({
    super.key,
    this.devicesStream,
    this.telemetrySource,
    this.unitPreference,
  });

  final Stream<UserDevicesState>? devicesStream;
  final DeviceTelemetrySource? telemetrySource;
  final TemperatureUnitPreference? unitPreference;

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
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
  void didUpdateWidget(DevicesPage oldWidget) {
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Your devices',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Manage your connected Yening Ecos devices '
            'from one place.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 22),

          StreamBuilder<UserDevicesState>(
            stream: _devices,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          'Unable to load your devices. Check your internet connection.',
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
              if (!snapshot.hasData || snapshot.data!.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              final devices = snapshot.data!.devices;
              if (devices.isEmpty) {
                return AppEmptyState(
                  icon: Icons.devices_other_rounded,
                  title: 'No devices connected',
                  description: 'Your devices will appear here after you complete the setup process.',
                  actionLabel: 'Add Device',
                  actionIcon: Icons.add_rounded,
                  onAction: () => _openAddDevice(context),
                );
              }
              return Column(
                children: [
                  for (final device in devices)
                    UserDeviceCard(
                      key: ValueKey(device.deviceId),
                      device: device,
                      onTap: () => _openDevice(device),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _openAddDevice(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Device'),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          _DeviceSetupInfoCard(
            title: 'How device setup works',
            steps: const [
              'Put your device into setup mode.',
              'Connect your phone to the device.',
              'Configure its Wi-Fi connection.',
              'Finish setup and start monitoring.',
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceSetupInfoCard extends StatelessWidget {
  const _DeviceSetupInfoCard({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.route_rounded,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          for (var index = 0; index < steps.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == steps.length - 1 ? 0 : 14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        steps[index],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
