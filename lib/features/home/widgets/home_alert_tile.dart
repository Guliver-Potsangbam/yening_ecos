import 'package:flutter/material.dart';

import 'package:yening_ecos/features/alerts/alerts_details_page.dart';
import 'package:yening_ecos/features/alerts/models/alert_models.dart';

class HomeAlertTile extends StatelessWidget {
  const HomeAlertTile({super.key, required this.alert});

  final DeviceAlert alert;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final Color backgroundColor;
    final Color iconColor;

    switch (alert.severity) {
      case AlertSeverity.critical:
        backgroundColor = colorScheme.errorContainer;
        iconColor = colorScheme.onErrorContainer;

      case AlertSeverity.warning:
        backgroundColor = colorScheme.tertiaryContainer;
        iconColor = colorScheme.onTertiaryContainer;

      case AlertSeverity.info:
        backgroundColor = colorScheme.secondaryContainer;
        iconColor = colorScheme.onSecondaryContainer;
    }

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AlertDetailsPage(alert: alert)),
        );
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(alert.icon, size: 20, color: iconColor),
        ),
        title: Text(
          alert.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            '${alert.deviceName} • ${alert.time}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      ),
    );
  }
}
