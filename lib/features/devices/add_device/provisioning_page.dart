import 'package:flutter/material.dart';

import '../data/mock_device_registry.dart';
import '../services/device_provisioning_service.dart';
import 'name_device_page.dart';

enum _ProvisioningStep {
  connectingToDevice,
  provisioningWifi,
  connectingToWifi,
  connectingToFirebase,
  completed,
  failed,
}

class ProvisioningPage extends StatefulWidget {
  const ProvisioningPage({
    super.key,
    required this.device,
    required this.wifiNetwork,
    required this.wifiPassword,
    required this.provisioningService,
  });

  final MockPhysicalDevice device;
  final String wifiNetwork;
  final String wifiPassword;

  final DeviceProvisioningService provisioningService;

  @override
  State<ProvisioningPage> createState() => _ProvisioningPageState();
}

class _ProvisioningPageState extends State<ProvisioningPage> {
  _ProvisioningStep _step = _ProvisioningStep.connectingToDevice;

  String _message = 'Connecting to your device...';

  @override
  void initState() {
    super.initState();

    MockDeviceRegistry.updateSetupStatus(
      deviceId: widget.device.deviceId,
      status: DeviceSetupStatus.provisioning,
    );

    _startProvisioning();
  }

  Future<void> _startProvisioning() async {
    try {
      setState(() {
        _step = _ProvisioningStep.connectingToDevice;
        _message = 'Connecting to your device...';
      });

      final connected = await widget.provisioningService.connectToDevice(
        widget.device,
      );

      if (!mounted) {
        return;
      }

      if (!connected) {
        _setFailure('Could not connect to the device.');
        return;
      }

      setState(() {
        _step = _ProvisioningStep.provisioningWifi;
        _message = 'Sending Wi-Fi settings to your device...';
      });

      final wifiProvisioned = await widget.provisioningService.provisionWifi(
        device: widget.device,
        ssid: widget.wifiNetwork,
        password: widget.wifiPassword,
      );

      if (!mounted) {
        return;
      }

      if (!wifiProvisioned) {
        _setFailure('Could not configure Wi-Fi on the device.');
        return;
      }

      setState(() {
        _step = _ProvisioningStep.connectingToWifi;
        _message = 'Connecting the device to Wi-Fi...';
      });

      final wifiConnected = await widget.provisioningService
          .waitForWifiConnection(widget.device);

      if (!mounted) {
        return;
      }

      if (!wifiConnected) {
        _setFailure('The device could not connect to Wi-Fi.');
        return;
      }

      setState(() {
        _step = _ProvisioningStep.connectingToFirebase;
        _message = 'Connecting the device to Firebase...';
      });

      final firebaseConnected = await widget.provisioningService
          .waitForFirebaseConnection(widget.device);

      if (!mounted) {
        return;
      }

      if (!firebaseConnected) {
        _setFailure('The device could not connect to Firebase.');
        return;
      }

      MockDeviceRegistry.updateSetupStatus(
        deviceId: widget.device.deviceId,
        status: DeviceSetupStatus.online,
      );

      setState(() {
        _step = _ProvisioningStep.completed;
        _message = 'Your device is online and ready.';
      });

      await Future<void>.delayed(const Duration(milliseconds: 800));

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => NameDevicePage(device: widget.device),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _setFailure('Something went wrong during device setup.');
    }
  }

  void _setFailure(String message) {
    MockDeviceRegistry.updateSetupStatus(
      deviceId: widget.device.deviceId,
      status: DeviceSetupStatus.failed,
    );

    setState(() {
      _step = _ProvisioningStep.failed;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final completed = _step == _ProvisioningStep.completed;

    final failed = _step == _ProvisioningStep.failed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Setup'),
        automaticallyImplyLeading: failed,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatusIcon(
                    icon: failed
                        ? Icons.error_outline_rounded
                        : completed
                        ? Icons.cloud_done_rounded
                        : Icons.sync_rounded,
                    backgroundColor: failed
                        ? colorScheme.errorContainer
                        : completed
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    iconColor: failed
                        ? colorScheme.onErrorContainer
                        : completed
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.primary,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    failed
                        ? 'Setup could not be completed'
                        : completed
                        ? 'Device connected'
                        : 'Setting up your device',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _ProvisioningProgress(step: _step),
                  if (!completed && !failed) ...[
                    const SizedBox(height: 28),
                    const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 44, color: iconColor),
      ),
    );
  }
}

class _ProvisioningProgress extends StatelessWidget {
  const _ProvisioningProgress({required this.step});

  final _ProvisioningStep step;

  @override
  Widget build(BuildContext context) {
    const items = [
      (label: 'Connect to device', step: _ProvisioningStep.connectingToDevice),
      (label: 'Configure Wi-Fi', step: _ProvisioningStep.provisioningWifi),
      (label: 'Connect to Wi-Fi', step: _ProvisioningStep.connectingToWifi),
      (
        label: 'Connect to Firebase',
        step: _ProvisioningStep.connectingToFirebase,
      ),
      (label: 'Device online', step: _ProvisioningStep.completed),
    ];

    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _ProgressItem(
            label: items[index].label,
            state: _resolveState(items[index].step),
          ),
          if (index != items.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }

  _ProgressItemState _resolveState(_ProvisioningStep itemStep) {
    if (step == _ProvisioningStep.failed) {
      return _ProgressItemState.pending;
    }

    if (step == _ProvisioningStep.completed) {
      return _ProgressItemState.completed;
    }

    final currentIndex = _stepIndex(step);

    final itemIndex = _stepIndex(itemStep);

    if (itemIndex < currentIndex) {
      return _ProgressItemState.completed;
    }

    if (itemIndex == currentIndex) {
      return _ProgressItemState.active;
    }

    return _ProgressItemState.pending;
  }

  int _stepIndex(_ProvisioningStep step) {
    return switch (step) {
      _ProvisioningStep.connectingToDevice => 0,
      _ProvisioningStep.provisioningWifi => 1,
      _ProvisioningStep.connectingToWifi => 2,
      _ProvisioningStep.connectingToFirebase => 3,
      _ProvisioningStep.completed => 4,
      _ProvisioningStep.failed => 0,
    };
  }
}

enum _ProgressItemState { pending, active, completed }

class _ProgressItem extends StatelessWidget {
  const _ProgressItem({required this.label, required this.state});

  final String label;
  final _ProgressItemState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final active = state == _ProgressItemState.active;

    final completed = state == _ProgressItemState.completed;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: completed
                ? colorScheme.primary
                : active
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            completed
                ? Icons.check_rounded
                : active
                ? Icons.more_horiz_rounded
                : Icons.circle_outlined,
            size: 19,
            color: completed
                ? colorScheme.onPrimary
                : active
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: active || completed
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: active || completed
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
