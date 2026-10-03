import 'package:flutter/material.dart';

import '../data/mock_device_catalog.dart';
import '../data/mock_device_registry.dart';
import '../services/mock_device_provisioning.dart';
import 'wifi_setup_page.dart';

class ClaimDevicePage extends StatelessWidget {
  const ClaimDevicePage({super.key, required this.device});

  final MockPhysicalDevice device;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final definition = MockDeviceCatalog.deviceByTypeId(device.deviceTypeId);

    final variant = definition?.variantById(device.variantId);

    return Scaffold(
      appBar: AppBar(title: const Text('Claim Device')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      definition?.icon ?? Icons.sensors_rounded,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          definition?.name ?? 'Device',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          variant?.name ?? 'Variant',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Ready to add this device?',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Claiming this device associates it with your account. You will then configure its Wi-Fi connection.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 24),
            _DeviceInformationCard(device: device),
            const SizedBox(height: 28),
            _ClaimDeviceButton(device: device),
          ],
        ),
      ),
    );
  }
}

class _ClaimDeviceButton extends StatefulWidget {
  const _ClaimDeviceButton({required this.device});

  final MockPhysicalDevice device;

  @override
  State<_ClaimDeviceButton> createState() => _ClaimDeviceButtonState();
}

class _ClaimDeviceButtonState extends State<_ClaimDeviceButton> {
  bool _isClaiming = false;

  Future<void> _claimDevice() async {
    if (_isClaiming) {
      return;
    }

    setState(() {
      _isClaiming = true;
    });

    final messenger = ScaffoldMessenger.of(context);

    final claimed = await MockDeviceProvisioning.claimDevice(
      widget.device.setupCode,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isClaiming = false;
    });

    if (claimed == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('This device could not be claimed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => WifiSetupPage(device: claimed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: _isClaiming ? null : _claimDevice,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: _isClaiming
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : const Text('Claim device'),
    );
  }
}

class _DeviceInformationCard extends StatelessWidget {
  const _DeviceInformationCard({required this.device});

  final MockPhysicalDevice device;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final items = [
      ('Serial number', device.serialNumber),
      ('Device ID', device.deviceId),
    ];

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
                      items[index].$1,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    flex: 2,
                    child: Text(
                      items[index].$2,
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
