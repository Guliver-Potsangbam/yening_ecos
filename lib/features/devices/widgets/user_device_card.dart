import 'package:flutter/material.dart';

import '../models/user_device.dart';

class UserDeviceCard extends StatelessWidget {
  const UserDeviceCard({
    super.key,
    required this.device,
    this.onTap,
    this.telemetry,
  });

  final UserDevice device;
  final VoidCallback? onTap;
  final Widget? telemetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.sensors_rounded,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.deviceName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          device.deviceId,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (device.serialNumber.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Serial: ${device.serialNumber}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          'Added to your account',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right_rounded),
                ],
              ),
              if (telemetry != null) ...[
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 18),
                telemetry!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
