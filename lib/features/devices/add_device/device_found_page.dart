import 'package:flutter/material.dart';

import '../data/mock_device_catalog.dart';
import '../data/mock_device_registry.dart';
import '../services/mock_device_provisioning.dart';
import 'claim_device_page.dart';
import 'device_lookup_source.dart';
import 'scan_device_page.dart';
import 'wifi_setup_page.dart';

class DeviceFoundPage extends StatelessWidget {
  const DeviceFoundPage({
    super.key,
    required this.deviceCode,
    required this.source,
  });

  final String deviceCode;
  final DeviceLookupSource source;

  MockPhysicalDevice? get _physicalDevice {
    return MockDeviceRegistry.findBySetupCode(deviceCode);
  }

  @override
  Widget build(BuildContext context) {
    final physicalDevice = _physicalDevice;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          source == DeviceLookupSource.qr ? 'Scan Result' : 'Device Lookup',
        ),
      ),
      body: physicalDevice == null
          ? _buildDeviceNotFound(context)
          : _buildDeviceFound(context, physicalDevice),
    );
  }

  Widget _buildDeviceNotFound(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.devices_other_rounded,
                        size: 42,
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Device not recognised',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The device code does not match a recognised physical device.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Code: $deviceCode',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: () {
                        if (source == DeviceLookupSource.qr) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const ScanDevicePage(),
                            ),
                          );
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: Icon(
                        source == DeviceLookupSource.qr
                            ? Icons.qr_code_scanner_rounded
                            : Icons.keyboard_rounded,
                      ),
                      label: Text(
                        source == DeviceLookupSource.qr
                            ? 'Scan again'
                            : 'Enter another code',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeviceFound(BuildContext context, MockPhysicalDevice device) {
    final colorScheme = Theme.of(context).colorScheme;

    final definition = MockDeviceCatalog.deviceByTypeId(device.deviceTypeId);

    final variant = definition?.variantById(device.variantId);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          _buildStatusBanner(context, device),
          const SizedBox(height: 24),
          Text(
            definition?.name ?? 'Unknown device',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            definition?.description ?? 'Recognised physical device',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 24),
          _DeviceInformationCard(
            items: [
              _DeviceInformationItem(
                label: 'Variant',
                value: variant?.name ?? device.variantId,
              ),
              _DeviceInformationItem(
                label: 'Serial number',
                value: device.serialNumber,
              ),
              _DeviceInformationItem(
                label: 'Device ID',
                value: device.deviceId,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildAction(context, device),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, MockPhysicalDevice device) {
    final colorScheme = Theme.of(context).colorScheme;

    final definition = MockDeviceCatalog.deviceByTypeId(device.deviceTypeId);

    final isOwnedByCurrentUser =
        device.ownerId == MockDeviceProvisioning.currentCustomerId;

    Color backgroundColor;
    Color foregroundColor;
    IconData icon;
    String title;
    String message;

    if (!device.isClaimed) {
      backgroundColor = colorScheme.primaryContainer;
      foregroundColor = colorScheme.onPrimaryContainer;
      icon = definition?.icon ?? Icons.sensors_rounded;
      title = 'Device found';
      message = 'This device is available to be added to your account.';
    } else if (isOwnedByCurrentUser && !device.isSetupComplete) {
      backgroundColor = colorScheme.secondaryContainer;
      foregroundColor = colorScheme.onSecondaryContainer;
      icon = Icons.settings_rounded;
      title = 'Setup incomplete';
      message =
          'This device belongs to your account, but its setup is not complete.';
    } else if (isOwnedByCurrentUser && device.isSetupComplete) {
      backgroundColor = colorScheme.primaryContainer;
      foregroundColor = colorScheme.onPrimaryContainer;
      icon = Icons.check_circle_outline_rounded;
      title = 'Device already set up';
      message = 'This device is already configured for your account.';
    } else {
      backgroundColor = colorScheme.errorContainer;
      foregroundColor = colorScheme.onErrorContainer;
      icon = Icons.lock_outline_rounded;
      title = 'Device already registered';
      message = 'This device is already associated with another account.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foregroundColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: foregroundColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context, MockPhysicalDevice device) {
    final isOwnedByCurrentUser =
        device.ownerId == MockDeviceProvisioning.currentCustomerId;

    final customerDevice = MockDeviceProvisioning.findCustomerDevice(
      device.deviceId,
    );

    if (!device.isClaimed) {
      return FilledButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ClaimDevicePage(device: device)),
          );
        },
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: const Text('Continue'),
      );
    }

    if (isOwnedByCurrentUser &&
        customerDevice != null &&
        customerDevice.isInactive) {
      return FilledButton(
        onPressed: () {
          final restored = MockDeviceProvisioning.restoreDevice(
            device.deviceId,
          );

          if (!restored) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not add the device back.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device added back to My Devices.'),
              behavior: SnackBarBehavior.floating,
            ),
          );

          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: const Text('Add back'),
      );
    }

    if (isOwnedByCurrentUser && !device.isSetupComplete) {
      return FilledButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WifiSetupPage(device: device)),
          );
        },
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: const Text('Continue setup'),
      );
    }

    if (isOwnedByCurrentUser && device.isSetupComplete) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: const Text('Already added'),
      );
    }

    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: const Text('Already registered'),
    );
  }
}

class _DeviceInformationCard extends StatelessWidget {
  const _DeviceInformationCard({required this.items});

  final List<_DeviceInformationItem> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      items[index].label,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    flex: 2,
                    child: Text(
                      items[index].value,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            if (index != items.length - 1)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class _DeviceInformationItem {
  const _DeviceInformationItem({required this.label, required this.value});

  final String label;
  final String value;
}
