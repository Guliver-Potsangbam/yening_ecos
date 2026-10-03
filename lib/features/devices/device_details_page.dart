import 'package:flutter/material.dart';

import 'data/customer_devices.dart';
import 'data/mock_device_catalog.dart';
import 'edit_device_name_page.dart';
import 'models/device_models.dart';
import 'services/mock_device_provisioning.dart';

class DeviceDetailsPage extends StatefulWidget {
  const DeviceDetailsPage({super.key, required this.device});

  final CustomerDevice device;

  @override
  State<DeviceDetailsPage> createState() => _DeviceDetailsPageState();
}

class _DeviceDetailsPageState extends State<DeviceDetailsPage> {
  bool _isRemoving = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CustomerDevice>>(
      valueListenable: CustomerDevices.devices,
      builder: (context, customerDevices, child) {
        final currentDevice = customerDevices.firstWhere(
          (device) => device.deviceId == widget.device.deviceId,
          orElse: () => widget.device,
        );

        return _buildPage(context, currentDevice);
      },
    );
  }

  Widget _buildPage(BuildContext context, CustomerDevice device) {
    final colorScheme = Theme.of(context).colorScheme;

    final definition = MockDeviceCatalog.deviceByTypeId(device.deviceTypeId);

    final variant = definition?.variantById(device.variantId);

    return Scaffold(
      appBar: AppBar(
        title: Text(device.deviceName),
        actions: [
          IconButton(
            onPressed: () => _editDeviceName(device),
            tooltip: 'Edit device name',
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _buildDeviceHeader(context, device, definition, variant),
            const SizedBox(height: 20),
            _buildStatusSection(context),
            if (variant != null && variant.sensors.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionTitle(context, 'Live readings'),
              const SizedBox(height: 10),
              _buildReadingsGrid(context, variant.sensors),
            ],
            if (variant != null && variant.controls.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionTitle(context, 'Controls'),
              const SizedBox(height: 10),
              _buildControls(context, variant.controls),
            ],
            const SizedBox(height: 20),
            _buildDeviceHealth(context),
            const SizedBox(height: 20),
            _buildDeviceInformation(context, device, definition, variant),
            const SizedBox(height: 28),
            _buildRemoveButton(context, device),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceHeader(
    BuildContext context,
    CustomerDevice device,
    DeviceDefinition? definition,
    DeviceVariant? variant,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              definition?.icon ?? Icons.sensors_rounded,
              size: 30,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.deviceName,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${definition?.name ?? device.deviceTypeId} · ${variant?.name ?? device.variantId}',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          const _StatusIndicator(
            label: 'Online',
            colorType: _StatusColorType.success,
            icon: Icons.check_circle_rounded,
          ),
          const Spacer(),
          Text(
            'Last updated just now',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildReadingsGrid(
    BuildContext context,
    List<SensorDefinition> sensors,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sensors.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        return _SensorReadingCard(sensor: sensors[index]);
      },
    );
  }

  Widget _buildControls(
    BuildContext context,
    List<ControlDefinition> controls,
  ) {
    return Column(
      children: [
        for (var index = 0; index < controls.length; index++) ...[
          _ControlCard(control: controls[index]),
          if (index != controls.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildDeviceHealth(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Device health',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const _HealthChip(),
            ],
          ),
          const SizedBox(height: 16),
          const _HealthItem(
            label: 'Connection',
            value: 'Stable',
            icon: Icons.wifi_rounded,
          ),
          const SizedBox(height: 12),
          const _HealthItem(
            label: 'Device uptime',
            value: '12 days 8 hours',
            icon: Icons.schedule_rounded,
          ),
          const SizedBox(height: 12),
          const _HealthItem(
            label: 'Firmware',
            value: '1.0.0',
            icon: Icons.system_update_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInformation(
    BuildContext context,
    CustomerDevice device,
    DeviceDefinition? definition,
    DeviceVariant? variant,
  ) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device information',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          _InformationRow(
            label: 'Device type',
            value: definition?.name ?? device.deviceTypeId,
          ),
          _InformationRow(
            label: 'Variant',
            value: variant?.name ?? device.variantId,
          ),
          _InformationRow(label: 'Device ID', value: device.deviceId),
          _InformationRow(label: 'Serial number', value: device.serialNumber),
        ],
      ),
    );
  }

  Widget _buildRemoveButton(BuildContext context, CustomerDevice device) {
    return OutlinedButton.icon(
      onPressed: _isRemoving ? null : () => _removeDevice(context, device),
      icon: _isRemoving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.remove_circle_outline_rounded),
      label: Text(_isRemoving ? 'Removing...' : 'Remove from My Devices'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    );
  }

  Future<void> _editDeviceName(CustomerDevice device) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditDeviceNamePage(device: device)),
    );
  }

  Future<void> _removeDevice(
    BuildContext context,
    CustomerDevice device,
  ) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove device?'),
          content: const Text(
            'This device will be removed from My Devices, but it will remain linked to your account. You can add it back later.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true) {
      return;
    }

    setState(() {
      _isRemoving = true;
    });

    final removed = MockDeviceProvisioning.removeDevice(device.deviceId);

    if (!mounted) {
      return;
    }

    if (!removed) {
      setState(() {
        _isRemoving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not remove the device.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    Navigator.of(context).pop();
  }
}

class _SensorReadingCard extends StatelessWidget {
  const _SensorReadingCard({required this.sensor});

  final SensorDefinition sensor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(sensor.icon, size: 20, color: colorScheme.primary),
              const Spacer(),
              _SensorStatusChip(status: sensor.status),
            ],
          ),
          const Spacer(),
          Text(
            sensor.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  sensor.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (sensor.unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Text(
                    sensor.unit,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            sensor.trend,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ControlCard extends StatefulWidget {
  const _ControlCard({required this.control});

  final ControlDefinition control;

  @override
  State<_ControlCard> createState() => _ControlCardState();
}

class _ControlCardState extends State<_ControlCard> {
  bool _enabled = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _enabled
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              widget.control.icon,
              color: _enabled
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.control.name,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.control.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (widget.control.type == ControlType.switchControl)
            Switch(
              value: _enabled,
              onChanged: (value) {
                setState(() {
                  _enabled = value;
                });
              },
            )
          else
            IconButton.filledTonal(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${widget.control.name} activated.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

enum _StatusColorType { success }

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    required this.label,
    required this.colorType,
    required this.icon,
  });

  final String label;
  final _StatusColorType colorType;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final color = switch (colorType) {
      _StatusColorType.success => colorScheme.primary,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 7),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

class _SensorStatusChip extends StatelessWidget {
  const _SensorStatusChip({required this.status});

  final SensorStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (label, color) = switch (status) {
      SensorStatus.normal => ('Normal', colorScheme.primary),
      SensorStatus.good => ('Good', colorScheme.primary),
      SensorStatus.optimal => ('Optimal', colorScheme.primary),
      SensorStatus.warning => ('Warning', colorScheme.secondary),
      SensorStatus.critical => ('Critical', colorScheme.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Healthy',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HealthItem extends StatelessWidget {
  const _HealthItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 19, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
