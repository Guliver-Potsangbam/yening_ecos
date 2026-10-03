import 'package:flutter/material.dart';

import 'package:yening_ecos/features/alerts/data/alerts_data.dart';

class HomeNavigationBar extends StatelessWidget {
  const HomeNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        const NavigationDestination(
          icon: Icon(Icons.sensors_outlined),
          selectedIcon: Icon(Icons.sensors_rounded),
          label: 'Devices',
        ),
        NavigationDestination(
          icon: Badge.count(
            count: AlertsData.unreadCount,
            isLabelVisible: AlertsData.unreadCount > 0,
            child: const Icon(Icons.notifications_none_rounded),
          ),
          selectedIcon: Badge.count(
            count: AlertsData.unreadCount,
            isLabelVisible: AlertsData.unreadCount > 0,
            child: const Icon(Icons.notifications_rounded),
          ),
          label: 'Alerts',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    );
  }
}
