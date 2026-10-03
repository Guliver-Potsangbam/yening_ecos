import 'package:flutter/material.dart';

import '../data/mock_device_registry.dart';
import '../services/device_provisioning_service.dart';
import '../services/mock_device_provisioning_service.dart';
import 'provisioning_page.dart';

class WifiSetupPage extends StatefulWidget {
  const WifiSetupPage({super.key, required this.device});

  final MockPhysicalDevice device;

  @override
  State<WifiSetupPage> createState() => _WifiSetupPageState();
}

class _WifiSetupPageState extends State<WifiSetupPage> {
  final DeviceProvisioningService _provisioningService =
      const MockDeviceProvisioningService();

  final TextEditingController _passwordController = TextEditingController();

  List<String> _networks = [];

  String? _selectedNetwork;

  bool _isLoadingNetworks = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadWifiNetworks();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadWifiNetworks() async {
    final networks = await _provisioningService.scanWifiNetworks();

    if (!mounted) {
      return;
    }

    setState(() {
      _networks = networks;
      _isLoadingNetworks = false;
    });
  }

  void _continue() {
    final network = _selectedNetwork;
    final password = _passwordController.text;

    if (network == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a Wi-Fi network.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the Wi-Fi password.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ProvisioningPage(
          device: widget.device,
          wifiNetwork: network,
          wifiPassword: password,
          provisioningService: _provisioningService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Wi-Fi')),
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
                  Icons.wifi_rounded,
                  size: 36,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Connect your device to Wi-Fi',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'Choose the Wi-Fi network that your device should use to access the internet.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              _buildNetworkField(context),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _isLoadingNetworks ? null : _continue,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Connect device'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkField(BuildContext context) {
    if (_isLoadingNetworks) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Wi-Fi network',
          prefixIcon: Icon(Icons.wifi_rounded),
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Scanning for networks...'),
          ],
        ),
      );
    }

    if (_networks.isEmpty) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Wi-Fi network',
          prefixIcon: Icon(Icons.wifi_rounded),
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            const Expanded(child: Text('No networks found')),
            IconButton(
              onPressed: _loadWifiNetworks,
              tooltip: 'Scan again',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedNetwork,
      decoration: const InputDecoration(
        labelText: 'Wi-Fi network',
        prefixIcon: Icon(Icons.wifi_rounded),
        border: OutlineInputBorder(),
      ),
      items: [
        for (final network in _networks)
          DropdownMenuItem(value: network, child: Text(network)),
      ],
      onChanged: (value) {
        setState(() {
          _selectedNetwork = value;
        });
      },
    );
  }
}
