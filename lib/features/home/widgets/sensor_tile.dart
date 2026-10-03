import 'package:flutter/material.dart';

import 'package:yening_ecos/features/devices/models/device_models.dart';

class SensorTile extends StatelessWidget {
  const SensorTile({super.key, required this.sensor});

  final SensorDefinition sensor;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (sensor.status) {
      SensorStatus.normal => 'Normal',
      SensorStatus.good => 'Good',
      SensorStatus.optimal => 'Optimal',
      SensorStatus.warning => 'Warning',
      SensorStatus.critical => 'Critical',
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(sensor.icon, size: 19),
                const Spacer(),
                Text(
                  sensor.trend,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const Spacer(),
            Text(sensor.name, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  sensor.value,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (sensor.unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      sensor.unit,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
