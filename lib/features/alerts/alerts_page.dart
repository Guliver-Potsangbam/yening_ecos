import 'package:flutter/material.dart';
import 'package:yening_ecos/features/alerts/alerts_details_page.dart';
import 'package:yening_ecos/widgets/alert_filter_chip.dart';
import 'package:yening_ecos/widgets/no_alerts_animation.dart';

import 'data/alerts_data.dart';
import 'models/alert_models.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  AlertSeverity? _selectedSeverity;

  List<DeviceAlert> get _filteredAlerts {
    final alerts = AlertsData.all;

    if (_selectedSeverity == null) {
      return alerts;
    }

    return alerts
        .where((alert) => alert.severity == _selectedSeverity)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _filteredAlerts;
    final unreadCount = AlertsData.unreadCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _buildOverviewCard(context, unreadCount),
        const SizedBox(height: 20),
        _buildSeverityFilter(context),
        const SizedBox(height: 16),
        _buildSectionHeader(context, alerts.length),
        const SizedBox(height: 10),
        if (alerts.isEmpty)
          _buildEmptyState(context)
        else
          _buildAlertsList(context, alerts),
      ],
    );
  }

  Widget _buildOverviewCard(BuildContext context, int unreadCount) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.notifications_active_outlined,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unreadCount == 0
                        ? 'All caught up'
                        : '$unreadCount active alerts',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unreadCount == 0
                        ? 'Your connected devices have no unread alerts.'
                        : 'Review recent events from your connected devices.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityFilter(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          AlertFilterChip(
            label: 'All',
            selected: _selectedSeverity == null,
            onSelected: () {
              setState(() {
                _selectedSeverity = null;
              });
            },
          ),
          const SizedBox(width: 8),
          AlertFilterChip(
            label: 'Critical',
            selected: _selectedSeverity == AlertSeverity.critical,
            onSelected: () {
              setState(() {
                _selectedSeverity = AlertSeverity.critical;
              });
            },
          ),
          const SizedBox(width: 8),
          AlertFilterChip(
            label: 'Warning',
            selected: _selectedSeverity == AlertSeverity.warning,
            onSelected: () {
              setState(() {
                _selectedSeverity = AlertSeverity.warning;
              });
            },
          ),
          const SizedBox(width: 8),
          AlertFilterChip(
            label: 'Info',
            selected: _selectedSeverity == AlertSeverity.info,
            onSelected: () {
              setState(() {
                _selectedSeverity = AlertSeverity.info;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, int count) {
    return Row(
      children: [
        Text(
          'Recent alerts',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        Text(
          '$count',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildAlertsList(BuildContext context, List<DeviceAlert> alerts) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int index = 0; index < alerts.length; index++) ...[
            _AlertListTile(alert: alerts[index]),
            if (index != alerts.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NoAlertsAnimation(size: 150),
          const SizedBox(height: 8),
          Text(
            'No alerts',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Everything is operating normally.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AlertListTile extends StatelessWidget {
  const _AlertListTile({required this.alert});

  final DeviceAlert alert;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final Color iconBackground;
    final Color iconColor;
    final String severityText;

    switch (alert.severity) {
      case AlertSeverity.critical:
        iconBackground = colorScheme.errorContainer;
        iconColor = colorScheme.onErrorContainer;
        severityText = 'Critical';

      case AlertSeverity.warning:
        iconBackground = colorScheme.tertiaryContainer;
        iconColor = colorScheme.onTertiaryContainer;
        severityText = 'Warning';

      case AlertSeverity.info:
        iconBackground = colorScheme.secondaryContainer;
        iconColor = colorScheme.onSecondaryContainer;
        severityText = 'Info';
    }

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AlertDetailsPage(alert: alert)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(alert.icon, size: 21, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: alert.isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                        ),
                      ),
                      if (alert.isUnread)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 6),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    alert.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Icon(
                        Icons.sensors_outlined,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          alert.deviceName,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('•', style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(width: 8),
                      Text(
                        alert.time,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: iconBackground,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          severityText,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: iconColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Icon(Icons.chevron_right_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
