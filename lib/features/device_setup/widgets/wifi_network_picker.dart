import 'package:flutter/material.dart';

import '../models/wifi_network.dart';
import '../services/wifi_provisioning_service.dart';

class WifiNetworkPicker extends StatelessWidget {
  const WifiNetworkPicker({
    super.key,
    required this.networks,
    required this.selected,
    required this.manualEntry,
    required this.scanning,
    required this.enabled,
    required this.ssidController,
    required this.onSelected,
    required this.onScan,
    required this.onToggleManual,
    this.scanMessage,
  });

  final List<WifiNetwork> networks;
  final WifiNetwork? selected;
  final bool manualEntry;
  final bool scanning;
  final bool enabled;
  final TextEditingController ssidController;
  final ValueChanged<WifiNetwork?> onSelected;
  final VoidCallback onScan;
  final VoidCallback onToggleManual;
  final String? scanMessage;

  @override
  Widget build(BuildContext context) {
    final canEdit = enabled && !scanning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Nearby 2.4 GHz networks')),
            TextButton.icon(
              onPressed: canEdit ? onScan : null,
              icon: scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(scanning ? 'Scanning…' : 'Scan again'),
            ),
          ],
        ),
        if (scanMessage != null) ...[
          Text(scanMessage!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
        ],
        if (manualEntry)
          TextFormField(
            controller: ssidController,
            enabled: canEdit,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Wi-Fi network name',
              hintText: 'Enter the exact Wi-Fi name',
              prefixIcon: Icon(Icons.wifi_rounded),
            ),
            validator: (value) =>
                WifiProvisioningService.validateSsid(value ?? ''),
          )
        else
          DropdownButtonFormField<WifiNetwork>(
            key: ObjectKey(selected),
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Wi-Fi network',
              prefixIcon: Icon(Icons.wifi_rounded),
            ),
            hint: const Text('Choose your Wi-Fi network'),
            items: [
              for (final network in networks)
                DropdownMenuItem(
                  value: network,
                  enabled: network.isSupported,
                  child: Text(
                    '${network.ssid} · ${network.signalLabel} · '
                    '${network.isSupported ? network.security : 'Unsupported security'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: canEdit ? onSelected : null,
            validator: (value) => value == null || !value.isSupported
                ? 'Choose a supported Wi-Fi network.'
                : null,
          ),
        TextButton(
          onPressed: canEdit && (manualEntry ? networks.isNotEmpty : true)
              ? onToggleManual
              : null,
          child: Text(
            manualEntry ? 'Choose a nearby network' : 'Enter a hidden network',
          ),
        ),
      ],
    );
  }
}
