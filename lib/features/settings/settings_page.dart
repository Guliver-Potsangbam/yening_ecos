import 'package:flutter/material.dart';
import 'package:yening_ecos/features/onboarding/data/onboarding_storage.dart';

import '../../core/preferences/temperature_unit_preference.dart';
import '../devices/widgets/temperature_unit_selector.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _pushNotifications = true;
  bool _deviceAlerts = true;
  bool _maintenanceAlerts = true;
  bool _sound = true;
  bool _vibration = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Notifications',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Push notifications'),
                  subtitle: const Text(
                    'Receive important notifications from your account.',
                  ),
                  value: _pushNotifications,
                  onChanged: (value) {
                    setState(() {
                      _pushNotifications = value;
                    });
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.warning_amber_outlined),
                  title: const Text('Device alerts'),
                  subtitle: const Text(
                    'Get notified when a device reports an issue.',
                  ),
                  value: _deviceAlerts,
                  onChanged: (value) {
                    setState(() {
                      _deviceAlerts = value;
                    });
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.build_outlined),
                  title: const Text('Maintenance alerts'),
                  subtitle: const Text(
                    'Receive maintenance and service notifications.',
                  ),
                  value: _maintenanceAlerts,
                  onChanged: (value) {
                    setState(() {
                      _maintenanceAlerts = value;
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'App experience',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined),
                  title: const Text('Sound'),
                  subtitle: const Text('Play notification sounds.'),
                  value: _sound,
                  onChanged: (value) {
                    setState(() {
                      _sound = value;
                    });
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration_rounded),
                  title: const Text('Vibration'),
                  subtitle: const Text(
                    'Use vibration for important notifications.',
                  ),
                  value: _vibration,
                  onChanged: (value) {
                    setState(() {
                      _vibration = value;
                    });
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ValueListenableBuilder<TemperatureUnit>(
                  valueListenable: TemperatureUnitPreference.instance,
                  builder: (context, unit, _) => ListTile(
                    leading: const Icon(Icons.thermostat_outlined),
                    title: const Text('Temperature unit'),
                    subtitle: Text(unit.label),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _showTemperatureUnitSelector,
                  ),
                ),
                TextButton.icon(
                  onPressed: _resetOnboarding,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset onboarding'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Support',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text('Help & Support'),
                  subtitle: const Text(
                    'Get help with your devices and account.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About'),
                  subtitle: const Text('App version and company information.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              'Version 1.0.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetOnboarding() async {
    final messenger = ScaffoldMessenger.of(context);

    await OnboardingStorage.resetOnboarding();

    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Onboarding reset successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showTemperatureUnitSelector() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    Text('Temperature unit'),
                    SizedBox(height: 16),
                    TemperatureUnitSelector(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
