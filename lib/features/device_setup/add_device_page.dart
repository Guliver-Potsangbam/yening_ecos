import 'package:flutter/material.dart';
import 'package:yening_ecos/features/device_setup/device_setup_page.dart';

class AddDevicePage extends StatelessWidget {
  const AddDevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Device')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Set up your device',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 12),

            Text(
              'We will identify your physical Yening Ecos '
              'device, configure its Wi-Fi connection, '
              'and add it to your account.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(height: 1.5),
            ),

            const SizedBox(height: 32),

            const _SetupStep(
              number: 1,
              icon: Icons.power_settings_new_rounded,
              title: 'Power on your device',
              description:
                  'Make sure your device is powered on '
                  'and ready for setup.',
            ),

            const _SetupStep(
              number: 2,
              icon: Icons.wifi_rounded,
              title: 'Put the device in setup mode',
              description:
                  'The device will create a temporary '
                  'Yening-Eco-Setup Wi-Fi network for your phone. '
                  'For this firmware, restart the device to reopen setup.',
            ),

            const _SetupStep(
              number: 3,
              icon: Icons.phone_android_rounded,
              title: 'Connect to the device',
              description:
                  'Yening Ecos will connect to the device '
                  'and verify its identity.',
            ),

            const _SetupStep(
              number: 4,
              icon: Icons.router_rounded,
              title: 'Configure your Wi-Fi',
              description:
                  'Choose the Wi-Fi network that the '
                  'device should use for internet access. '
                  'Use a 2.4 GHz network.',
            ),

            const _SetupStep(
              number: 5,
              icon: Icons.check_circle_outline_rounded,
              title: 'Finish setup',
              description:
                  'The device will be connected to your '
                  'account and ready to use.',
            ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed: () async {
                final completed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const DeviceSetupPage()),
                );
                if (completed == true && context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Start Setup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  final int number;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(radius: 24, child: Icon(icon)),

              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$number',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
