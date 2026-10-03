import 'package:flutter/material.dart';

import 'package:yening_ecos/features/alerts/data/alerts_data.dart';
import 'package:yening_ecos/features/devices/device_details_page.dart';
import 'package:yening_ecos/features/devices/models/device_models.dart';
import 'package:yening_ecos/features/devices/widgets/device_info_item.dart';
import 'package:yening_ecos/features/home/widgets/control_tile.dart';
import 'package:yening_ecos/features/home/widgets/home_alert_tile.dart';
import 'package:yening_ecos/features/home/widgets/home_trend_card.dart';
import 'package:yening_ecos/features/home/widgets/sensor_tile.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({
    super.key,
    required this.device,
    required this.deviceDefinition,
    required this.variant,
    required this.chartData,
    required this.selectedRange,
    required this.onRangeChanged,
    required this.onSwitchDevice,
    required this.onViewAllAlerts,
  });

  final CustomerDevice device;
  final DeviceDefinition deviceDefinition;
  final DeviceVariant variant;

  final Map<String, List<double>> chartData;
  final String selectedRange;

  final ValueChanged<String> onRangeChanged;
  final VoidCallback onSwitchDevice;
  final VoidCallback onViewAllAlerts;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _buildSystemStatus(context),
          const SizedBox(height: 20),
          _buildCurrentDeviceSection(context),
          const SizedBox(height: 20),
          _buildSensorSection(context),
          const SizedBox(height: 20),
          HomeTrendCard(
            deviceTypeId: device.deviceTypeId,
            chartData: chartData,
            selectedRange: selectedRange,
            onRangeChanged: onRangeChanged,
          ),
          const SizedBox(height: 20),
          _buildControlsSection(context),
          const SizedBox(height: 20),
          _buildDeviceHealth(context),
          const SizedBox(height: 20),
          _buildLatestAlerts(context),
        ],
      ),
    );
  }

  Widget _buildSystemStatus(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'All systems operational',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Text('Updated just now', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildCurrentDeviceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Current device',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton(onPressed: onSwitchDevice, child: const Text('Switch')),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeviceDetailsPage(device: device),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          deviceDefinition.icon,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.deviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${deviceDefinition.name} ${variant.name}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DeviceInfoItem(
                          label: 'Device ID',
                          value: device.deviceId,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DeviceInfoItem(
                          label: 'Serial number',
                          value: device.serialNumber,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSensorSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Live readings',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '${variant.sensors.length} sensors',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: variant.sensors.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.55,
          ),
          itemBuilder: (context, index) {
            return SensorTile(sensor: variant.sensors[index]);
          },
        ),
      ],
    );
  }

  Widget _buildControlsSection(BuildContext context) {
    if (variant.controls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick controls',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (int index = 0; index < variant.controls.length; index++) ...[
                ControlTile(
                  control: variant.controls[index],
                  initiallyEnabled: index == 0,
                ),
                if (index != variant.controls.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceHealth(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Device health',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '94%',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              value: 0.94,
              minHeight: 7,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 17),
                const SizedBox(width: 6),
                Text(
                  'Power normal',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  'Last seen 18 sec ago',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestAlerts(BuildContext context) {
    final latestAlerts = AlertsData.latest(2);

    if (latestAlerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Latest alerts',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton(
              onPressed: onViewAllAlerts,
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int index = 0; index < latestAlerts.length; index++) ...[
                HomeAlertTile(alert: latestAlerts[index]),
                if (index != latestAlerts.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
