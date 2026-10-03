import 'package:flutter/material.dart';

import 'models/alert_models.dart';

class AlertDetailsPage extends StatefulWidget {
  const AlertDetailsPage({super.key, required this.alert});

  final DeviceAlert alert;

  @override
  State<AlertDetailsPage> createState() => _AlertDetailsPageState();
}

class _AlertDetailsPageState extends State<AlertDetailsPage> {
  bool _acknowledged = false;

  DeviceAlert get alert => widget.alert;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final _SeverityPresentation severity = switch (alert.severity) {
      AlertSeverity.critical => const _SeverityPresentation(
        label: 'Critical',
        icon: Icons.error_rounded,
      ),
      AlertSeverity.warning => const _SeverityPresentation(
        label: 'Warning',
        icon: Icons.warning_amber_rounded,
      ),
      AlertSeverity.info => const _SeverityPresentation(
        label: 'Information',
        icon: Icons.info_outline_rounded,
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert Details'),
        elevation: 1.5,
        scrolledUnderElevation: 2,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.16),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _buildStatusHeader(context, severity),
          const SizedBox(height: 20),
          _buildAlertSection(context),
          const SizedBox(height: 20),
          _buildDeviceSection(context),
          const SizedBox(height: 20),
          _buildRecommendedAction(context),
          const SizedBox(height: 24),
          _buildActionButton(context),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(
    BuildContext context,
    _SeverityPresentation severity,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    final Color backgroundColor;
    final Color foregroundColor;

    switch (alert.severity) {
      case AlertSeverity.critical:
        backgroundColor = colorScheme.errorContainer;
        foregroundColor = colorScheme.onErrorContainer;

      case AlertSeverity.warning:
        backgroundColor = colorScheme.tertiaryContainer;
        foregroundColor = colorScheme.onTertiaryContainer;

      case AlertSeverity.info:
        backgroundColor = colorScheme.secondaryContainer;
        foregroundColor = colorScheme.onSecondaryContainer;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(severity.icon, color: foregroundColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        severity.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foregroundColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        alert.title,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.schedule_outlined, size: 17),
                const SizedBox(width: 7),
                Text(alert.time, style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                _StatusChip(
                  label: _acknowledged ? 'Acknowledged' : 'Active',
                  active: !_acknowledged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertSection(BuildContext context) {
    return _SectionCard(
      title: 'What happened',
      icon: Icons.description_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alert.message,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 18),
          const _DetailRow(
            label: 'Detected',
            value: '8 minutes ago',
            icon: Icons.access_time_rounded,
          ),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Source',
            value: alert.deviceName,
            icon: Icons.sensors_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSection(BuildContext context) {
    return _SectionCard(
      title: 'Affected device',
      icon: Icons.sensors_outlined,
      child: Column(
        children: [
          _DetailRow(
            label: 'Device name',
            value: alert.deviceName,
            icon: Icons.sensors_rounded,
          ),
          const SizedBox(height: 14),
          const _DetailRow(
            label: 'Device ID',
            value: 'device-gas-001',
            icon: Icons.fingerprint_rounded,
          ),
          const SizedBox(height: 14),
          const _DetailRow(
            label: 'Serial number',
            value: 'GC-IND-2026-000001',
            icon: Icons.confirmation_number_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedAction(BuildContext context) {
    return _SectionCard(
      title: 'Recommended action',
      icon: Icons.lightbulb_outline_rounded,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.arrow_forward_rounded,
              size: 19,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _recommendation,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _recommendation {
    switch (alert.severity) {
      case AlertSeverity.critical:
        return 'Check the affected device immediately and verify the surrounding environment before continuing normal operation.';

      case AlertSeverity.warning:
        return 'Review the latest device reading and verify whether the condition returns to its normal operating range.';

      case AlertSeverity.info:
        return 'No immediate action is required. Continue monitoring the device for further changes.';
    }
  }

  Widget _buildActionButton(BuildContext context) {
    if (_acknowledged) {
      return OutlinedButton.icon(
        onPressed: null,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        icon: const Icon(Icons.check_circle_outline_rounded),
        label: const Text('Alert acknowledged'),
      );
    }

    return FilledButton.icon(
      onPressed: () {
        setState(() {
          _acknowledged = true;
        });
      },
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      icon: const Icon(Icons.done_rounded),
      label: const Text('Acknowledge alert'),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 9),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const Spacer(),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.tertiaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SeverityPresentation {
  const _SeverityPresentation({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
