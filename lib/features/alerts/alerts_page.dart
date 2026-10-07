import 'package:flutter/material.dart';

import '../../widgets/app_empty_state.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Alerts',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Important events from your connected devices '
            'will appear here.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 22),

          AppEmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'All clear',
            description:
                'There are no alerts to review right now. '
                'When a connected device needs your attention, '
                'it will appear here.',
          ),

          const SizedBox(height: 20),

          _AlertInfoCard(
            icon: Icons.notifications_active_outlined,
            title: 'Stay informed',
            description:
                'Yening Ecos can bring important device '
                'events into one notification center.',
          ),

          const SizedBox(height: 12),

          _AlertInfoCard(
            icon: Icons.tune_rounded,
            title: 'Control what matters',
            description:
                'Alert behavior and notification preferences '
                'can be configured as your connected devices grow.',
          ),
        ],
      ),
    );
  }
}

class _AlertInfoCard extends StatelessWidget {
  const _AlertInfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colorScheme.onTertiaryContainer),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
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
