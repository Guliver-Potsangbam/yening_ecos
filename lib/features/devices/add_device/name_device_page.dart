import 'package:flutter/material.dart';

import '../data/mock_device_catalog.dart';
import '../data/mock_device_registry.dart';
import '../services/mock_device_provisioning.dart';

class NameDevicePage extends StatefulWidget {
  const NameDevicePage({super.key, required this.device});

  final MockPhysicalDevice device;

  @override
  State<NameDevicePage> createState() => _NameDevicePageState();
}

class _NameDevicePageState extends State<NameDevicePage> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();

    final definition = MockDeviceCatalog.deviceByTypeId(
      widget.device.deviceTypeId,
    );

    _nameController = TextEditingController(
      text: definition?.name ?? 'My Device',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _finish() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a device name.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final added = MockDeviceProvisioning.addToCustomerDevices(
      device: widget.device,
      deviceName: name,
    );

    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This device is already in your account.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final definition = MockDeviceCatalog.deviceByTypeId(
      widget.device.deviceTypeId,
    );

    final variant = definition?.variantById(widget.device.variantId);

    return Scaffold(
      appBar: AppBar(title: const Text('Name Device')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  definition?.icon ?? Icons.sensors_rounded,
                  size: 36,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Give your device a name',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'Choose a name that makes this device easy to recognise in your account.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _finish(),
                decoration: InputDecoration(
                  labelText: 'Device name',
                  hintText: definition?.name ?? 'Enter a name',
                  prefixIcon: Icon(definition?.icon ?? Icons.devices_rounded),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
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
                      variant?.name ?? '',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.device.serialNumber,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _finish,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Finish setup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
