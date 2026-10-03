import 'package:flutter/material.dart';

import 'package:yening_ecos/features/alerts/data/alerts_data.dart';
import 'package:yening_ecos/features/devices/data/mock_device_catalog.dart';
import 'package:yening_ecos/features/devices/models/device_models.dart';

class HomeAppDrawer extends StatelessWidget {
  const HomeAppDrawer({
    super.key,
    required this.devices,
    required this.selectedDeviceIndex,
    required this.onDashboardSelected,
    required this.onDevicesSelected,
    required this.onAlertsSelected,
    required this.onProfileSelected,
    required this.onDeviceSelected,
    required this.onSettingsSelected,
    required this.onSignOutSelected,
  });

  final List<CustomerDevice> devices;
  final int selectedDeviceIndex;

  final VoidCallback onDashboardSelected;
  final VoidCallback onDevicesSelected;
  final VoidCallback onAlertsSelected;
  final VoidCallback onProfileSelected;
  final ValueChanged<int> onDeviceSelected;

  final VoidCallback onSettingsSelected;
  final Future<void> Function() onSignOutSelected;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _buildUserHeader(context),
            const Divider(),

            _buildNavigationItem(
              context,
              icon: Icons.dashboard_outlined,
              title: 'Overview',
              onTap: onDashboardSelected,
            ),

            _buildNavigationItem(
              context,
              icon: Icons.sensors_outlined,
              title: 'My Devices',
              onTap: onDevicesSelected,
            ),

            ListTile(
              leading: const Icon(Icons.notifications_none_rounded),
              title: const Text('Alerts'),
              trailing: AlertsData.unreadCount > 0
                  ? Badge.count(count: AlertsData.unreadCount)
                  : null,
              onTap: () {
                Navigator.of(context).pop();
                onAlertsSelected();
              },
            ),

            _buildNavigationItem(
              context,
              icon: Icons.person_outline_rounded,
              title: 'Profile',
              onTap: onProfileSelected,
            ),

            const SizedBox(height: 8),
            const Divider(),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Your devices',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),

            Expanded(
              child: ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];

                  final definition = MockDeviceCatalog.deviceByTypeId(
                    device.deviceTypeId,
                  );

                  final variant = definition?.variantById(device.variantId);

                  if (definition == null || variant == null) {
                    return const SizedBox.shrink();
                  }

                  return ListTile(
                    selected: index == selectedDeviceIndex,
                    leading: Icon(definition.icon),
                    title: Text(device.deviceName),
                    subtitle: Text('${definition.name} ${variant.name}'),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () {
                      Navigator.of(context).pop();
                      onDeviceSelected(index);
                    },
                  );
                },
              ),
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
                onSettingsSelected();
              },
            ),

            ListTile(
              leading: const Icon(Icons.help_outline_rounded),
              title: const Text('Help & Support'),
              onTap: () {
                Navigator.of(context).pop();
              },
            ),

            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About'),
              onTap: () {
                Navigator.of(context).pop();
              },
            ),

            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign out'),
              onTap: () async {
                Navigator.of(context).pop();
                await onSignOutSelected();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            child: Text(
              'G',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guliver Potsangbam',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${devices.length} connected devices',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }
}
